# frozen_string_literal: true

require "test_helper"

require "securerandom"

class ReleasesApiTest < ActionDispatch::IntegrationTest
  test "history is newest-first and marks exactly the current immutable Release" do
    site, first_release, second_release = site_with_two_releases("first-site")
    site.update!(current_release: second_release)

    host! "localhost"
    get "/api/v1/sites/#{site.slug}/releases", as: :json
    assert_response :unauthorized
    assert_equal({ "error" => { "code" => "authentication_required" } }, response.parsed_body)

    with_bootstrap_token do |token|
      get "/api/v1/sites/#{site.slug}/releases", headers: bearer_headers(token), as: :json

      assert_response :ok
      assert_equal(
        {
          "site" => { "slug" => "first-site", "current_release_number" => 2 },
          "releases" => [
            release_payload(second_release, current: true),
            release_payload(first_release, current: false)
          ],
          "pagination" => { "limit" => 50, "next_before" => nil }
        },
        response.parsed_body
      )

      get "/api/v1/sites/#{site.slug}/releases?limit=1", headers: bearer_headers(token), as: :json
      assert_response :ok
      assert_equal [ 2 ], response.parsed_body.fetch("releases").pluck("number")
      assert_equal({ "limit" => 1, "next_before" => 2 }, response.parsed_body.fetch("pagination"))

      get "/api/v1/sites/#{site.slug}/releases?limit=1&before=2", headers: bearer_headers(token), as: :json
      assert_response :ok
      assert_equal [ 1 ], response.parsed_body.fetch("releases").pluck("number")
      assert_equal({ "limit" => 1, "next_before" => nil }, response.parsed_body.fetch("pagination"))

      get "/api/v1/sites/#{site.slug}/releases?limit=101", headers: bearer_headers(token), as: :json
      assert_response :unprocessable_entity
      assert_equal({ "error" => { "code" => "invalid_pagination" } }, response.parsed_body)
    end
  end

  test "rollback requires a key and returns the exact recorded result on replay" do
    site, first_release, second_release = site_with_two_releases("first-site")
    site.update!(current_release: second_release)
    key = "synthetic-private-rollback-key"

    with_bootstrap_token do |token|
      host! "localhost"
      path = "/api/v1/sites/#{site.slug}/releases/#{first_release.number}/rollback"

      post path, headers: bearer_headers(token), as: :json
      assert_response :unprocessable_entity
      assert_equal({ "error" => { "code" => "idempotency_key_required" } }, response.parsed_body)

      post path, headers: bearer_headers(token).merge("Idempotency-Key" => key), as: :json
      assert_response :created
      created_payload = response.parsed_body
      assert_equal(
        {
          "site_slug" => site.slug,
          "from_release_number" => 2,
          "to_release_number" => 1,
          "resulting_release_number" => 1,
          "changed" => true
        },
        created_payload.fetch("rollback").except("id", "recorded_at")
      )
      assert_kind_of Integer, created_payload.dig("rollback", "id")
      assert_match(/\A\d{4}-\d{2}-\d{2}T/, created_payload.dig("rollback", "recorded_at"))
      assert_equal first_release, site.reload.current_release

      second_key = SecureRandom.urlsafe_base64(32, false)
      post "/api/v1/sites/#{site.slug}/releases/#{second_release.number}/rollback",
        headers: bearer_headers(token).merge("Idempotency-Key" => second_key),
        as: :json
      assert_response :created
      assert_equal second_release, site.reload.current_release

      post path, headers: bearer_headers(token).merge("Idempotency-Key" => key), as: :json
      assert_response :ok
      assert_equal created_payload, response.parsed_body
      assert_equal second_release, site.reload.current_release,
        "replaying an old result must not move the current pointer again"

      post "/api/v1/sites/#{site.slug}/releases/#{second_release.number}/rollback",
        headers: bearer_headers(token).merge("Idempotency-Key" => key),
        as: :json
      assert_response :conflict
      assert_equal({ "error" => { "code" => "idempotency_conflict" } }, response.parsed_body)
      assert_equal second_release, site.reload.current_release
    end
  end

  test "rollback does not leak a Release from another Site" do
    site, _first_release, second_release = site_with_two_releases("first-site")
    site.update!(current_release: second_release)
    other_site, = site_with_two_releases("other-site")
    private_release = other_site.releases.create!(
      number: 3,
      manifest_sha256: "f" * 64,
      finalized_at: Time.current
    )

    with_bootstrap_token do |token|
      host! "localhost"
      post "/api/v1/sites/#{site.slug}/releases/#{private_release.number}/rollback",
        headers: bearer_headers(token).merge("Idempotency-Key" => SecureRandom.urlsafe_base64(32, false)),
        as: :json

      assert_response :not_found
      assert_equal({ "error" => { "code" => "release_not_found" } }, response.parsed_body)
      refute_includes response.body, other_site.slug
      refute_includes response.body, private_release.manifest_sha256
      assert_equal second_release, site.reload.current_release
    end
  end

  private

  def site_with_two_releases(slug)
    site = Site.create!(slug:, name: slug.titleize)
    first = release_with_entries(site:, number: 1, digest_character: "a", sizes: [ 3 ])
    second = release_with_entries(site:, number: 2, digest_character: "b", sizes: [ 5, 7 ])
    [ site, first, second ]
  end

  def release_with_entries(site:, number:, digest_character:, sizes:)
    release = site.releases.create!(
      number:,
      manifest_sha256: digest_character * 64,
      finalized_at: Time.utc(2026, 7, 20, 12, number, 0)
    )
    sizes.each_with_index do |size, index|
      digest = Digest::SHA256.hexdigest("#{site.slug}-#{number}-#{index}")
      blob = Blob.create!(sha256: digest, byte_size: size, storage_key: digest)
      release.manifest_entries.create!(
        blob:,
        path: index.zero? ? "index.html" : "asset-#{index}.txt",
        byte_size: size,
        content_type: index.zero? ? "text/html" : "text/plain",
        offline_policy: index.zero? ? "required" : "download"
      )
    end
    release
  end

  def release_payload(release, current:)
    {
      "id" => release.id,
      "number" => release.number,
      "manifest_sha256" => release.manifest_sha256,
      "finalized_at" => release.finalized_at.iso8601(6),
      "current" => current,
      "files" => release.manifest_entries.length,
      "bytes" => release.manifest_entries.sum(&:byte_size)
    }
  end

  def bearer_headers(token)
    { "Authorization" => "Bearer #{token}" }
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
