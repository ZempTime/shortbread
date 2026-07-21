# frozen_string_literal: true

require "test_helper"

require "digest"
require "securerandom"
require "tmpdir"

class ReleasePublishDeltaTest < ActionDispatch::IntegrationTest
  test "a second publish reports path deltas and deduplicates shared new Blob uploads" do
    site = Site.create!(slug: "first-site", name: "First Site")
    base_contents = {
      "index.html" => "first index",
      "kept.txt" => "kept bytes",
      "removed.txt" => "removed bytes"
    }
    next_contents = {
      "index.html" => "second index",
      "kept.txt" => "kept bytes",
      "added-one.txt" => "shared new bytes",
      "added-two.txt" => "shared new bytes"
    }

    with_blob_root do
      with_bootstrap_token do |token|
        host! "localhost"
        first_plan = create_plan(site:, contents: base_contents, token:)
        upload_missing(first_plan, contents: base_contents, token:)
        first_release = finalize(first_plan, token:)

        key = SecureRandom.urlsafe_base64(32, false)
        second_plan = create_plan(site:, contents: next_contents, token:, idempotency_key: key)

        assert_equal(
          { "added" => 2, "changed" => 1, "reused" => 1, "removed" => 1 },
          second_plan.fetch("delta")
        )
        assert_equal 2, second_plan.fetch("uploads").length,
          "two added paths sharing one new Blob must need only one upload"
        assert_equal(
          next_contents.values_at("index.html", "added-one.txt").map { |body| Digest::SHA256.hexdigest(body) }.sort,
          second_plan.fetch("uploads").pluck("sha256").sort
        )

        replayed_plan = create_plan(
          site:,
          contents: next_contents,
          token:,
          idempotency_key: key,
          expected_status: :ok
        )
        assert_equal second_plan, replayed_plan

        upload_missing(second_plan, contents: next_contents, token:)
        second_release = finalize(second_plan, token:)

        assert_equal 1, first_release.fetch("number")
        assert_equal 2, second_release.fetch("number")
        assert_equal second_release.fetch("id"), site.reload.current_release_id
        assert_equal base_contents.keys.sort, Release.find(first_release.fetch("id")).manifest_entries.pluck(:path).sort
        assert_equal next_contents.keys.sort, Release.find(second_release.fetch("id")).manifest_entries.pluck(:path).sort

        replayed_release = finalize(second_plan, token:, expected_status: :ok)
        assert_equal second_release, replayed_release
        assert_equal 2, site.releases.count
      end
    end
  end

  private

  def create_plan(site:, contents:, token:, idempotency_key: SecureRandom.urlsafe_base64(32, false), expected_status: :created)
    post "/api/v1/sites/#{site.slug}/publish-plans",
      params: { manifest: { entries: manifest_entries(contents) } },
      headers: bearer_headers(token).merge("Idempotency-Key" => idempotency_key),
      as: :json
    assert_response expected_status
    response.parsed_body.fetch("publish_plan")
  end

  def finalize(plan, token:, expected_status: :created)
    post plan.fetch("finalize_url"), headers: bearer_headers(token), as: :json
    assert_response expected_status
    response.parsed_body.fetch("release")
  end

  def upload_missing(plan, contents:, token:)
    content_by_digest = contents.values.to_h { |body| [ Digest::SHA256.hexdigest(body), body ] }
    plan.fetch("uploads").each do |upload|
      put upload.fetch("url"),
        params: content_by_digest.fetch(upload.fetch("sha256")),
        headers: bearer_headers(token).merge("Content-Type" => "application/octet-stream")
      assert_response :no_content
    end
  end

  def manifest_entries(contents)
    contents.map do |path, body|
      {
        path:,
        sha256: Digest::SHA256.hexdigest(body),
        size: body.bytesize,
        content_type: path.end_with?(".html") ? "text/html" : "text/plain",
        offline_policy: path == "index.html" ? "required" : "download"
      }
    end
  end

  def bearer_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def with_blob_root
    previous = ENV["SHORTBREAD_BLOB_ROOT"]
    Dir.mktmpdir("shortbread-release-delta") do |root|
      ENV["SHORTBREAD_BLOB_ROOT"] = root
      yield
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
