# frozen_string_literal: true

require "digest"

module ReleaseRollbacks
  Result = Data.define(:rollback, :created) do
    def changed = rollback.from_release_id != rollback.to_release_id
    def from_release = rollback.from_release
    def to_release = rollback.to_release
  end

  class IdempotencyKeyRequired < StandardError; end
  class IdempotencyConflict < StandardError; end
  class ReleaseNotFound < StandardError; end
  class NoCurrentRelease < StandardError; end

  module_function

  def perform(site:, release_number:, idempotency_key:, now: Time.current)
    key = idempotency_key.to_s
    raise IdempotencyKeyRequired if key.empty? || key.bytesize > 512 || key.match?(/[\r\n]/)

    key_digest = Digest::SHA256.hexdigest(key)
    Site.transaction do
      locked_site = Site.lock.find(site.id)
      existing = locked_site.release_rollbacks.find_by(idempotency_key_digest: key_digest)
      if existing
        raise IdempotencyConflict unless existing.to_release.number == release_number

        next Result.new(rollback: existing, created: false)
      end

      target = locked_site.releases.find_by(number: release_number)
      raise ReleaseNotFound unless target

      current = locked_site.current_release
      raise NoCurrentRelease unless current

      rollback = locked_site.release_rollbacks.create!(
        from_release: current,
        to_release: target,
        idempotency_key_digest: key_digest,
        created_at: now,
        updated_at: now
      )
      locked_site.update!(current_release: target) unless current == target
      Result.new(rollback:, created: true)
    end
  end
end
