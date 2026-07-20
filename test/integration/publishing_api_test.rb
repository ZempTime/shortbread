# frozen_string_literal: true

require "test_helper"

require "digest"
require "securerandom"
require "tmpdir"

class PublishingApiTest < ActionDispatch::IntegrationTest
  test "planning one HTML file returns one upload without exposing content or a Release" do
    site = Site.create!(slug: "first-site", name: "First Site")
    content = "<h1>PRIVATE_HTML_MARKER</h1>"
    entry = {
      path: "index.html",
      sha256: Digest::SHA256.hexdigest(content),
      size: content.bytesize,
      content_type: "text/html",
      offline_policy: "required"
    }
    idempotency_key = SecureRandom.urlsafe_base64(32, false)

    with_bootstrap_token do |token|
      host! "localhost"

      assert_difference -> { PublishPlan.count }, 1 do
        post "/api/v1/sites/#{site.slug}/publish-plans",
          params: { manifest: { entries: [ entry ] } },
          headers: {
            "Authorization" => "Bearer #{token}",
            "Idempotency-Key" => idempotency_key
          },
          as: :json
      end

      assert_response :created
      payload = response.parsed_body.fetch("publish_plan")
      assert_equal "open", payload.fetch("state")
      assert_equal 1, payload.fetch("uploads").length
      upload = payload.fetch("uploads").first
      assert_equal entry[:sha256], upload.fetch("sha256")
      assert_equal entry[:size], upload.fetch("size")
      assert_equal "PUT", upload.fetch("method")
      assert_equal({ "Content-Type" => "application/octet-stream" }, upload.fetch("headers"))
      assert_predicate upload.fetch("url"), :present?
      assert_predicate payload.fetch("finalize_url"), :present?

      assert_equal 0, Release.count
      assert_equal 0, ManifestEntry.count
      assert_equal 0, Blob.count
      assert_nil site.reload.current_release_id
      refute_includes response.body, "index.html"
      refute_includes response.body, "PRIVATE_HTML_MARKER"
      refute_includes response.body, idempotency_key
    end
  end

  test "planning is idempotent for the same key and rejects conflicting reuse" do
    site = Site.create!(slug: "first-site", name: "First Site")
    entry = manifest_entry("first version")
    idempotency_key = SecureRandom.urlsafe_base64(32, false)

    with_bootstrap_token do |token|
      host! "localhost"
      headers = {
        "Authorization" => "Bearer #{token}",
        "Idempotency-Key" => idempotency_key
      }

      post "/api/v1/sites/#{site.slug}/publish-plans",
        params: { manifest: { entries: [ entry ] } }, headers:, as: :json
      assert_response :created
      plan_id = response.parsed_body.dig("publish_plan", "id")

      assert_no_difference -> { PublishPlan.count } do
        post "/api/v1/sites/#{site.slug}/publish-plans",
          params: { manifest: { entries: [ entry ] } }, headers:, as: :json
      end
      assert_response :ok
      assert_equal plan_id, response.parsed_body.dig("publish_plan", "id")

      assert_no_difference -> { PublishPlan.count } do
        post "/api/v1/sites/#{site.slug}/publish-plans",
          params: { manifest: { entries: [ manifest_entry("changed version") ] } }, headers:, as: :json
      end
      assert_response :conflict
      assert_equal "idempotency_conflict", response.parsed_body.dig("error", "code")

      assert_no_difference -> { PublishPlan.count } do
        post "/api/v1/sites/#{site.slug}/publish-plans",
          params: { manifest: { entries: [ entry ] } },
          headers: { "Authorization" => "Bearer #{token}" }, as: :json
      end
      assert_response :unprocessable_entity
      assert_equal "idempotency_key_required", response.parsed_body.dig("error", "code")
    end
  end

  test "planning rejects unsafe or incomplete Manifests without durable state" do
    site = Site.create!(slug: "first-site", name: "First Site")
    valid = manifest_entry("valid")
    invalid_entry_sets = [
      [ valid.merge(path: "../index.html") ],
      [ valid.merge(path: "/index.html") ],
      [ valid, valid.merge(path: "INDEX.HTML") ],
      [ valid.merge(path: "_shortbread/session") ],
      [ valid.merge(path: "service-worker.js") ],
      [ valid, valid.merge(path: ".env") ],
      [ valid, valid.merge(path: "caf\u00e9.html") ],
      [ valid, valid.merge(path: "index%2ehtml") ],
      [ valid.merge(sha256: "A" * 64) ],
      [ valid.merge(size: -1) ],
      [ valid.merge(content_type: "application/octet-stream") ],
      [ valid.merge(content_type: "text/html\nunsafe") ],
      [ valid.merge(offline_policy: "optional") ],
      [ valid.merge(offline_policy: "silent") ]
    ]

    with_bootstrap_token do |token|
      host! "localhost"

      invalid_entry_sets.each do |entries|
        assert_no_difference -> { PublishPlan.count } do
          post "/api/v1/sites/#{site.slug}/publish-plans",
            params: { manifest: { entries: } },
            headers: {
              "Authorization" => "Bearer #{token}",
              "Idempotency-Key" => SecureRandom.urlsafe_base64(32, false)
            },
            as: :json
        end
        assert_response :unprocessable_entity
        assert_equal "invalid_manifest", response.parsed_body.dig("error", "code")
      end
    end
  end

  test "planning rejects contradictory Blob sizes without revealing Manifest details" do
    site = Site.create!(slug: "first-site", name: "First Site")
    content = "shared bytes"
    index_entry = manifest_entry(content)
    contradictory_entry = index_entry.merge(
      path: "assets/copy.html",
      size: content.bytesize + 1
    )

    with_bootstrap_token do |token|
      host! "localhost"

      assert_no_difference -> { PublishPlan.count } do
        post "/api/v1/sites/#{site.slug}/publish-plans",
          params: { manifest: { entries: [ index_entry, contradictory_entry ] } },
          headers: {
            "Authorization" => "Bearer #{token}",
            "Idempotency-Key" => SecureRandom.urlsafe_base64(32, false)
          },
          as: :json
      end

      assert_response :unprocessable_entity
      assert_equal({ "error" => { "code" => "invalid_manifest" } }, response.parsed_body)
      refute_includes response.body, index_entry.fetch(:sha256)
      refute_includes response.body, contradictory_entry.fetch(:path)

      assert_difference -> { PublishPlan.count }, 1 do
        post "/api/v1/sites/#{site.slug}/publish-plans",
          params: {
            manifest: {
              entries: [ index_entry, contradictory_entry.merge(size: content.bytesize) ]
            }
          },
          headers: {
            "Authorization" => "Bearer #{token}",
            "Idempotency-Key" => SecureRandom.urlsafe_base64(32, false)
          },
          as: :json
      end

      assert_response :created
      assert_equal 1, response.parsed_body.dig("publish_plan", "uploads").length
    end
  end

  test "a mismatched upload creates neither a usable Blob nor a Release" do
    site = Site.create!(slug: "first-site", name: "First Site")
    content = "PRIVATE_EXPECTED_CONTENT"

    with_blob_root do |blob_root|
      with_bootstrap_token do |token|
        host! "localhost"
        upload = create_plan(site:, content:, token:).fetch("uploads").first

        assert_no_difference [ -> { Blob.count }, -> { Release.count }, -> { ManifestEntry.count } ] do
          put upload.fetch("url"),
            params: "PRIVATE_WRONG_CONTENT",
            headers: {
              "Authorization" => "Bearer #{token}",
              "Content-Type" => "application/octet-stream"
            }
        end

        assert_response :unprocessable_entity
        assert_equal "blob_content_mismatch", response.parsed_body.dig("error", "code")
        assert_nil site.reload.current_release_id
        refute LocalBlobStore.new(root: blob_root).verified?(
          storage_key: upload.fetch("sha256"),
          sha256: upload.fetch("sha256"),
          byte_size: content.bytesize
        )
      end
    end
  end

  test "an exact upload is private, verified, and idempotent without publishing" do
    site = Site.create!(slug: "first-site", name: "First Site")
    content = "<h1>PRIVATE_EXACT_CONTENT</h1>"
    idempotency_key = SecureRandom.urlsafe_base64(32, false)

    with_blob_root do |blob_root|
      with_bootstrap_token do |token|
        host! "localhost"
        publish_plan = create_plan(site:, content:, token:, idempotency_key:)
        upload = publish_plan.fetch("uploads").first
        headers = {
          "Authorization" => "Bearer #{token}",
          "Content-Type" => "application/octet-stream"
        }

        assert_difference -> { Blob.count }, 1 do
          put upload.fetch("url"), params: content, headers:
        end
        assert_response :no_content
        blob = Blob.find_by!(sha256: upload.fetch("sha256"))
        assert_equal content.bytesize, blob.byte_size

        store = LocalBlobStore.new(root: blob_root)
        stored = store.open(blob.storage_key) { |io| io.read }
        assert_equal content, stored

        assert_no_difference -> { Blob.count } do
          put upload.fetch("url"), params: content, headers:
        end
        assert_response :no_content

        post "/api/v1/sites/#{site.slug}/publish-plans",
          params: { manifest: { entries: [ manifest_entry(content) ] } },
          headers: bearer_headers(token).merge("Idempotency-Key" => idempotency_key),
          as: :json
        assert_response :ok
        assert_empty response.parsed_body.dig("publish_plan", "uploads")
        assert_equal 0, Release.count
        assert_equal 0, ManifestEntry.count
        assert_nil site.reload.current_release_id
      end
    end
  end

  test "finalize rejects an incomplete plan without creating partial records" do
    site = Site.create!(slug: "first-site", name: "First Site")

    with_blob_root do
      with_bootstrap_token do |token|
        host! "localhost"
        publish_plan = create_plan(site:, content: "expected bytes", token:)

        assert_no_difference [ -> { Release.count }, -> { ManifestEntry.count } ] do
          post publish_plan.fetch("finalize_url"), headers: bearer_headers(token), as: :json
        end

        assert_response :conflict
        assert_equal "publish_incomplete", response.parsed_body.dig("error", "code")
        assert_nil site.reload.current_release_id
        assert_equal "open", PublishPlan.find(publish_plan.fetch("id")).state
      end
    end
  end

  test "finalize atomically publishes one immutable Release and is idempotent" do
    site = Site.create!(slug: "first-site", name: "First Site")
    content = "<h1>PRIVATE_FINAL_CONTENT</h1>"

    with_blob_root do
      with_bootstrap_token do |token|
        host! "localhost"
        publish_plan = create_plan(site:, content:, token:)
        upload_content(publish_plan.fetch("uploads").first, content:, token:)

        assert_difference [ -> { Release.count }, -> { ManifestEntry.count } ], 1 do
          post publish_plan.fetch("finalize_url"), headers: bearer_headers(token), as: :json
        end
        assert_response :created
        payload = response.parsed_body.fetch("release")
        release = Release.find(payload.fetch("id"))
        assert_equal site, release.site
        assert_equal 1, release.number
        assert_equal release, site.reload.current_release
        assert_equal publish_plan.fetch("id"), PublishPlan.find_by!(release:).id

        entry = release.manifest_entries.sole
        assert_equal "index.html", entry.path
        assert_equal "text/html", entry.content_type
        assert_equal "required", entry.offline_policy
        assert_equal content.bytesize, entry.byte_size
        assert_equal Digest::SHA256.hexdigest(content), entry.blob.sha256
        refute_includes response.body, "index.html"
        refute_includes response.body, "PRIVATE_FINAL_CONTENT"

        assert_no_difference [ -> { Release.count }, -> { ManifestEntry.count } ] do
          post publish_plan.fetch("finalize_url"), headers: bearer_headers(token), as: :json
        end
        assert_response :ok
        assert_equal release.id, response.parsed_body.dig("release", "id")
      end
    end
  end

  test "a stale complete plan cannot replace a newer Release" do
    site = Site.create!(slug: "first-site", name: "First Site")
    content = "shared immutable bytes"

    with_blob_root do
      with_bootstrap_token do |token|
        host! "localhost"
        first_plan = create_plan(site:, content:, token:)
        second_plan = create_plan(site:, content:, token:)
        upload_content(first_plan.fetch("uploads").first, content:, token:)

        post first_plan.fetch("finalize_url"), headers: bearer_headers(token), as: :json
        assert_response :created
        first_release = site.reload.current_release

        assert_no_difference [ -> { Release.count }, -> { ManifestEntry.count } ] do
          post second_plan.fetch("finalize_url"), headers: bearer_headers(token), as: :json
        end
        assert_response :conflict
        assert_equal "stale_publish_plan", response.parsed_body.dig("error", "code")
        assert_equal first_release, site.reload.current_release
      end
    end
  end

  private

  def bearer_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def upload_content(upload, content:, token:)
    put upload.fetch("url"),
      params: content,
      headers: bearer_headers(token).merge("Content-Type" => "application/octet-stream")
    assert_response :no_content
  end

  def create_plan(site:, content:, token:, idempotency_key: SecureRandom.urlsafe_base64(32, false))
    post "/api/v1/sites/#{site.slug}/publish-plans",
      params: { manifest: { entries: [ manifest_entry(content) ] } },
      headers: {
        "Authorization" => "Bearer #{token}",
        "Idempotency-Key" => idempotency_key
      },
      as: :json
    assert_response :created
    response.parsed_body.fetch("publish_plan")
  end

  def manifest_entry(content)
    {
      path: "index.html",
      sha256: Digest::SHA256.hexdigest(content),
      size: content.bytesize,
      content_type: "text/html",
      offline_policy: "required"
    }
  end

  def with_blob_root
    previous = ENV["SHORTBREAD_BLOB_ROOT"]
    Dir.mktmpdir("shortbread-test-blobs") do |root|
      ENV["SHORTBREAD_BLOB_ROOT"] = root
      yield root
    ensure
      ENV["SHORTBREAD_BLOB_ROOT"] = previous
    end
  end

  def with_bootstrap_token
    previous = ENV["SHORTBREAD_BOOTSTRAP_TOKEN"]
    token = SecureRandom.urlsafe_base64(32)
    ENV["SHORTBREAD_BOOTSTRAP_TOKEN"] = token
    yield token
  ensure
    ENV["SHORTBREAD_BOOTSTRAP_TOKEN"] = previous
  end
end
