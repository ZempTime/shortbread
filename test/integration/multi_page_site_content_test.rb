# frozen_string_literal: true

require "test_helper"

require "digest"
require "stringio"
require "tmpdir"

class MultiPageSiteContentTest < ActionDispatch::IntegrationTest
  test "a non-index path in the current Release is served at its Manifest path" do
    pages = {
      "index.html" => "<h1>PRIVATE_INDEX</h1>",
      "chapter-2.html" => "<h1>PRIVATE_CHAPTER_TWO</h1>",
      "guides/setup.html" => "<h1>PRIVATE_NESTED_GUIDE</h1>"
    }

    with_multi_page_site(pages:) do |site, grant, digests|
      host! "#{site.slug}.sites.localhost"
      authenticate(grant:, site:)

      pages.each do |path, content|
        get "/#{path}"

        assert_response :ok, "#{path} was not served"
        assert_equal content, response.body
        assert_equal "text/html", response.headers["Content-Type"]
        assert_equal content.bytesize.to_s, response.headers["Content-Length"]
        assert_equal %Q("#{digests.fetch(path)}"), response.headers["ETag"]
        assert_equal "no-store", response.headers["Cache-Control"]
        assert_equal "nosniff", response.headers["X-Content-Type-Options"]
      end
    end
  end

  test "the site root still serves index.html" do
    pages = { "index.html" => "<h1>PRIVATE_ROOT</h1>", "other.html" => "<h1>PRIVATE_OTHER</h1>" }

    with_multi_page_site(pages:) do |site, grant, _digests|
      host! "#{site.slug}.sites.localhost"
      authenticate(grant:, site:)

      get "/"

      assert_response :ok
      assert_equal pages.fetch("index.html"), response.body
    end
  end

  test "a path absent from the Manifest is not found" do
    pages = { "index.html" => "<h1>PRIVATE_INDEX</h1>" }

    with_multi_page_site(pages:) do |site, grant, _digests|
      host! "#{site.slug}.sites.localhost"
      authenticate(grant:, site:)

      get "/missing.html"

      assert_response :not_found
      assert_empty response.body
      assert_nil response.headers["ETag"]
    end
  end

  test "a non-index path is refused without a Site session" do
    pages = {
      "index.html" => "<h1>PRIVATE_INDEX</h1>",
      "chapter-2.html" => "<h1>PRIVATE_CHAPTER_TWO</h1>"
    }

    with_multi_page_site(pages:) do |site, grant, _digests|
      host! "#{site.slug}.sites.localhost"

      get "/chapter-2.html"
      assert_response :not_found
      assert_empty response.body

      authenticate(grant:, site:)
      get "/chapter-2.html"
      assert_response :ok

      grant.update!(revoked_at: Time.current)
      get "/chapter-2.html"
      assert_response :not_found
      assert_empty response.body
    end
  end

  test "traversal and absolute-path requests never escape the Manifest" do
    pages = { "index.html" => "<h1>PRIVATE_INDEX</h1>", "guides/setup.html" => "<h1>PRIVATE_GUIDE</h1>" }

    with_multi_page_site(pages:) do |site, grant, _digests|
      host! "#{site.slug}.sites.localhost"
      authenticate(grant:, site:)

      [
        "/../config/database.yml",
        "/guides/../../secrets.txt",
        "/./guides/setup.html/../../index.html",
        "//etc/passwd"
      ].each do |path|
        get path

        assert_includes [ 400, 404 ], response.status, "#{path} was not refused"
        assert_empty response.body
      end
    end
  end

  # The catch-all route puts every unmatched Site path through this controller, including probes
  # like /robots.txt. An unreachable database must still fail closed rather than surfacing a 500.
  test "a Site path fails closed when the database is unreachable" do
    pages = { "index.html" => "<h1>PRIVATE_INDEX</h1>" }

    with_multi_page_site(pages:) do |site, grant, _digests|
      host! "#{site.slug}.sites.localhost"
      authenticate(grant:, site:)

      Site.stub(:find_by, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
        get "/robots.txt"
      end

      assert_response :not_found
      assert_empty response.body
    end
  end

  private

  def with_multi_page_site(pages:, slug: "first-site")
    Dir.mktmpdir("shortbread-multi-page-site") do |root|
      previous_root = ENV["SHORTBREAD_BLOB_ROOT"]
      ENV["SHORTBREAD_BLOB_ROOT"] = root

      site = Site.create!(slug:, name: "First Site")
      person = Person.create!(first_name: "Avery")
      grant = Grant.create!(site:, person:)
      store = LocalBlobStore.new
      digests = {}

      entries = pages.map do |path, content|
        digest = Digest::SHA256.hexdigest(content)
        digests[path] = digest
        storage_key = store.put_verified(
          io: StringIO.new(content),
          sha256: digest,
          byte_size: content.bytesize
        )
        blob = Blob.create!(sha256: digest, byte_size: content.bytesize, storage_key:)
        {
          blob:, path:, byte_size: content.bytesize,
          content_type: "text/html", offline_policy: "required"
        }
      end

      release = assemble_test_release!(
        site:, number: 1, manifest_sha256: Digest::SHA256.hexdigest("manifest"),
        finalized_at: Time.current, entries:
      )
      site.update!(current_release: release)

      yield site, grant, digests
    ensure
      ENV["SHORTBREAD_BLOB_ROOT"] = previous_root
    end
  end

  def authenticate(grant:, site:, scheme: "http")
    issued = SiteSession.issue(
      grant:,
      audience: "#{scheme}://#{site.slug}.sites.localhost",
      now: Time.current
    )
    cookies[SiteSession.cookie_name(secure: scheme == "https")] = issued.token
  end
end
