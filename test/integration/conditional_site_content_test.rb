# frozen_string_literal: true

require "test_helper"

require "digest"
require "stringio"
require "tmpdir"

class ConditionalSiteContentTest < ActionDispatch::IntegrationTest
  test "authorized GET and HEAD return 304 for the current content hash while revoked access stays hidden" do
    content = "<h1>PRIVATE_CONDITIONAL_CONTENT</h1>"

    with_private_site(content:) do |site, grant, etag|
      host! "#{site.slug}.sites.localhost"
      authenticate(grant:, site:)

      get "/"
      assert_response :ok
      assert_equal %Q("#{etag}"), response.headers.fetch("ETag")

      get "/", headers: { "If-None-Match" => response.headers.fetch("ETag") }
      assert_response :not_modified
      assert_empty response.body
      assert_equal %Q("#{etag}"), response.headers.fetch("ETag")

      head "/", headers: { "If-None-Match" => %Q("#{etag}") }
      assert_response :not_modified
      assert_empty response.body

      get "/", headers: { "If-None-Match" => %Q("#{"0" * 64}") }
      assert_response :ok
      assert_equal content, response.body

      grant.update!(revoked_at: Time.current)
      get "/", headers: { "If-None-Match" => %Q("#{etag}") }
      assert_response :not_found
      assert_empty response.body
      assert_nil response.headers["ETag"]
    end
  end

  private

  def with_private_site(content:)
    previous = ENV["SHORTBREAD_BLOB_ROOT"]
    Dir.mktmpdir("shortbread-conditional-site") do |root|
      ENV["SHORTBREAD_BLOB_ROOT"] = root
      site = Site.create!(slug: "first-site", name: "First Site")
      person = Person.create!(first_name: "Avery")
      grant = Grant.create!(site:, person:)
      digest = Digest::SHA256.hexdigest(content)
      store = LocalBlobStore.new(root:)
      storage_key = store.put_verified(io: StringIO.new(content), sha256: digest, byte_size: content.bytesize)
      blob = Blob.create!(sha256: digest, byte_size: content.bytesize, storage_key:)
      release = site.releases.create!(number: 1, manifest_sha256: "a" * 64, finalized_at: Time.current)
      release.manifest_entries.create!(
        blob:,
        path: "index.html",
        byte_size: content.bytesize,
        content_type: "text/html",
        offline_policy: "required"
      )
      site.update!(current_release: release)

      yield site, grant, digest
    ensure
      ENV["SHORTBREAD_BLOB_ROOT"] = previous
    end
  end

  def authenticate(grant:, site:)
    issued = SiteSession.issue(
      grant:,
      audience: "http://#{site.slug}.sites.localhost",
      now: Time.current
    )
    cookies[SiteSession.cookie_name(secure: false)] = issued.token
  end
end
