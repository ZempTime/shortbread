# frozen_string_literal: true

require "digest"

module Publishing
  PLAN_LIFETIME = 24.hours
  Result = Struct.new(:publish_plan, :created, keyword_init: true)
  FinalizeResult = Struct.new(:release, :created, keyword_init: true)

  class InvalidManifest < StandardError; end
  class IdempotencyKeyRequired < StandardError; end
  class IdempotencyConflict < StandardError; end
  class PublishIncomplete < StandardError; end
  class PublishPlanExpired < StandardError; end
  class StalePublishPlan < StandardError; end

  module_function

  def plan(site:, idempotency_key:, manifest:, now: Time.current)
    key = idempotency_key.to_s
    raise IdempotencyKeyRequired if key.empty? || key.bytesize > 512 || key.match?(/[\r\n]/)

    candidate_manifest = Manifest.build(entries: manifest.to_h.stringify_keys.fetch("entries", nil))
    normalized_manifest = { "entries" => candidate_manifest.entries }
    manifest_sha256 = candidate_manifest.sha256
    key_digest = Digest::SHA256.hexdigest(key)

    site.with_lock do
      existing = site.publish_plans.find_by(idempotency_key_digest: key_digest)
      if existing
        raise IdempotencyConflict unless existing.manifest_sha256 == manifest_sha256 && existing.manifest == normalized_manifest

        return Result.new(publish_plan: existing, created: false)
      end

      publish_plan = site.publish_plans.create!(
        base_release: site.current_release,
        idempotency_key_digest: key_digest,
        manifest_sha256:,
        manifest: normalized_manifest,
        state: "open",
        expires_at: now + PLAN_LIFETIME
      )
      Result.new(publish_plan:, created: true)
    end
  end

  def finalize(publish_plan:, blob_store:, now: Time.current)
    PublishPlan.transaction do
      publish_plan.lock!
      if publish_plan.release_id
        FinalizeResult.new(release: publish_plan.release, created: false)
      else
        raise PublishPlanExpired unless publish_plan.open? && publish_plan.expires_at > now

        entries = publish_plan.manifest.fetch("entries")
        manifest = Manifest.build(entries:)
        raise InvalidManifest unless manifest.sha256 == publish_plan.manifest_sha256

        blobs = preflight_blobs(entries:, blob_store:)

        site = Site.lock.find(publish_plan.site_id)
        raise StalePublishPlan unless site.current_release_id == publish_plan.base_release_id

        release = site.releases.create!(
          number: site.releases.maximum(:number).to_i + 1,
          manifest_sha256: publish_plan.manifest_sha256
        )
        entries.each do |entry|
          ManifestEntry.create!(
            release:,
            blob: blobs.fetch(entry.fetch("sha256")),
            path: entry.fetch("path"),
            byte_size: entry.fetch("size"),
            content_type: entry.fetch("content_type"),
            offline_policy: entry.fetch("offline_policy")
          )
        end
        release.update!(finalized_at: now)
        site.update!(current_release: release)
        publish_plan.update!(release:, state: "finalized", finalized_at: now)
        FinalizeResult.new(release:, created: true)
      end
    end
  end

  def normalize_manifest(manifest)
    entries = manifest.to_h.stringify_keys.fetch("entries", nil)
    raise InvalidManifest unless entries.is_a?(Array) && entries.any?

    normalized = entries.map { |entry| normalize_entry(entry.to_h.stringify_keys) }
    paths = normalized.map { |entry| entry.fetch("path") }
    raise InvalidManifest unless paths.include?("index.html")
    raise InvalidManifest unless paths.length == paths.uniq.length
    raise InvalidManifest unless paths.map(&:downcase).length == paths.map(&:downcase).uniq.length
    blob_sizes = normalized.group_by { |entry| entry.fetch("sha256") }.values
    raise InvalidManifest unless blob_sizes.all? { |entries| entries.map { |entry| entry.fetch("size") }.uniq.one? }

    index_entry = normalized.find { |entry| entry.fetch("path") == "index.html" }
    raise InvalidManifest unless index_entry.fetch("content_type") == "text/html"
    raise InvalidManifest unless index_entry.fetch("offline_policy") == "required"

    { "entries" => normalized.sort_by { |entry| entry.fetch("path") } }
  rescue KeyError, NoMethodError, TypeError
    raise InvalidManifest
  end

  def delta_for(publish_plan)
    candidate = Manifest.build(entries: publish_plan.manifest.fetch("entries"))
    candidate.delta_from(Manifest.from_release(publish_plan.base_release))
  end

  def preflight_blobs(entries:, blob_store:)
    entries.to_h do |entry|
      sha256 = entry.fetch("sha256")
      blob = Blob.find_by(sha256:)
      complete = blob &&
        blob.byte_size == entry.fetch("size") &&
        blob_store.verified?(storage_key: blob.storage_key, sha256:, byte_size: blob.byte_size)
      raise PublishIncomplete unless complete

      [ sha256, blob ]
    end
  end

  def normalize_entry(entry)
    path = entry.fetch("path")
    sha256 = entry.fetch("sha256")
    size = entry.fetch("size")
    content_type = entry.fetch("content_type")
    offline_policy = entry.fetch("offline_policy")
    raise InvalidManifest unless valid_path?(path)
    raise InvalidManifest unless sha256.is_a?(String) && sha256.match?(Blob::SHA256_FORMAT)
    raise InvalidManifest unless size.is_a?(Integer) && size >= 0
    raise InvalidManifest unless content_type.is_a?(String) && content_type.present? && content_type.bytesize <= 255
    raise InvalidManifest if content_type.match?(/[\r\n]/)
    raise InvalidManifest unless ManifestEntry::OFFLINE_POLICIES.include?(offline_policy)

    {
      "path" => path,
      "sha256" => sha256,
      "size" => size,
      "content_type" => content_type,
      "offline_policy" => offline_policy
    }
  end

  def valid_path?(path)
    return false unless path.is_a?(String) && path.present? && path.valid_encoding? && path.ascii_only?
    return false if path.start_with?("/") || path.include?("\\") || path.include?("\0")

    segments = path.split("/", -1)
    return false if segments.any? { |segment| segment.empty? || segment == "." || segment == ".." }
    return false unless segments.all? { |segment| segment.match?(/\A[A-Za-z0-9][A-Za-z0-9._-]*\z/) }
    return false if segments.any? { |segment| segment == ".env" || segment.start_with?(".env.") }
    return false if segments.first == "_shortbread"
    return false if path == "service-worker.js"

    true
  end
end
