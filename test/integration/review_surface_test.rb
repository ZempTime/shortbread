# frozen_string_literal: true

require "test_helper"

require "digest"
require "stringio"
require "tmpdir"

class ReviewSurfaceTest < ActionDispatch::IntegrationTest
  DOCUMENT = "<html><body><h1>Deploy notes</h1><p>Every change ships behind a flag.</p></body></html>"

  test "an HTML document is served with the review surface injected" do
    with_reviewable_site do |context|
      as_viewer(context)

      get "/"

      assert_response :ok
      assert_includes response.body, "Deploy notes", "the Release's own content was lost"
      assert_includes response.body, ReviewSurface::SCRIPT_PATH,
        "the review surface was not injected"
    end
  end

  test "the stored Release bytes are never modified by injection" do
    with_reviewable_site do |context|
      as_viewer(context)
      entry = context.fetch(:release).manifest_entries.find_by!(path: "index.html")

      get "/"

      stored = LocalBlobStore.new.open_verified(
        storage_key: entry.blob.storage_key, sha256: entry.blob.sha256, byte_size: entry.byte_size
      ).read

      assert_equal DOCUMENT, stored, "injection rewrote the content-addressed Blob"
      assert_equal Digest::SHA256.hexdigest(DOCUMENT), entry.blob.sha256
    end
  end

  test "the ETag stays the Blob digest so the Release remains content-addressed" do
    with_reviewable_site do |context|
      as_viewer(context)
      digest = context.fetch(:release).manifest_entries.find_by!(path: "index.html").blob.sha256

      get "/"

      assert_equal %Q("#{digest}"), response.headers["ETag"]
    end
  end

  test "a non-HTML Manifest entry is served untouched" do
    with_reviewable_site do |context|
      as_viewer(context)

      get "/data.json"

      assert_response :ok
      assert_equal context.fetch(:json), response.body
      assert_not_includes response.body, ReviewSurface::SCRIPT_PATH
    end
  end

  test "the review surface script is served on the Site host" do
    with_reviewable_site do |context|
      as_viewer(context)

      get ReviewSurface::SCRIPT_PATH

      assert_response :ok
      assert_includes response.headers["Content-Type"], "javascript"
      assert_includes response.body, "captureFromSelection"
    end
  end

  test "the review surface script requires a Site session" do
    with_reviewable_site do |_context|
      get ReviewSurface::SCRIPT_PATH

      assert_response :not_found
    end
  end

  # Criterion 3: reloading the Release paints the Comment on the same text. The server hands the
  # Viewer the Comments for this (Release, path) so the surface can repaint them.
  test "reloading a document delivers the Comments already anchored to it" do
    with_reviewable_site do |context|
      as_viewer(context)
      text = Shortbread::Extraction.from_html(DOCUMENT).text
      quote = "ships behind a flag"

      post "/_shortbread/comments", params: {
        body: "Which flag?", path: "index.html", quote:, start_offset: text.index(quote)
      }, as: :json
      assert_response :created

      get "/_shortbread/comments?path=index.html"

      assert_response :ok
      payload = JSON.parse(response.body)
      comment = payload.fetch("comments").sole
      assert_equal "Which flag?", comment.fetch("body")
      assert_equal quote, comment.fetch("quote")
      assert_equal text.index(quote), comment.fetch("startOffset")
      assert_equal "exact", comment.fetch("placement")
      assert_equal "Avery", comment.fetch("person")
    end
  end

  test "Comments are scoped to the Release and path they were anchored to" do
    with_reviewable_site do |context|
      as_viewer(context)
      text = Shortbread::Extraction.from_html(DOCUMENT).text
      quote = "ships behind a flag"

      post "/_shortbread/comments", params: {
        body: "On the index.", path: "index.html", quote:, start_offset: text.index(quote)
      }, as: :json
      assert_response :created

      get "/_shortbread/comments?path=other.html"

      assert_response :ok
      assert_empty JSON.parse(response.body).fetch("comments")
    end
  end

  test "listing Comments requires a Site session" do
    with_reviewable_site do |context|
      get "/_shortbread/comments?path=index.html"
      assert_response :not_found

      as_viewer(context)
      context.fetch(:grant).update!(revoked_at: Time.current)

      get "/_shortbread/comments?path=index.html"
      assert_response :not_found
    end
  end

  private

  def as_viewer(context)
    site = context.fetch(:site)
    host! "#{site.slug}.sites.localhost"
    issued = SiteSession.issue(
      grant: context.fetch(:grant),
      audience: "http://#{site.slug}.sites.localhost",
      now: Time.current
    )
    cookies[SiteSession.cookie_name(secure: false)] = issued.token
  end

  def with_reviewable_site(slug: "first-site")
    Dir.mktmpdir("shortbread-review-surface") do |root|
      previous_root = ENV["SHORTBREAD_BLOB_ROOT"]
      ENV["SHORTBREAD_BLOB_ROOT"] = root

      site = Site.create!(slug:, name: "First Site")
      person = Person.create!(first_name: "Avery")
      grant = Grant.create!(site:, person:)
      store = LocalBlobStore.new
      json = %({"released":true})

      entries = { "index.html" => [ DOCUMENT, "text/html" ], "data.json" => [ json, "application/json" ] }
        .map do |path, (content, content_type)|
          digest = Digest::SHA256.hexdigest(content)
          storage_key = store.put_verified(
            io: StringIO.new(content), sha256: digest, byte_size: content.bytesize
          )
          blob = Blob.create!(sha256: digest, byte_size: content.bytesize, storage_key:)
          {
            blob:, path:, byte_size: content.bytesize, content_type:, offline_policy: "required"
          }
        end

      release = assemble_test_release!(
        site:, number: 1, manifest_sha256: Digest::SHA256.hexdigest("manifest"),
        finalized_at: Time.current, entries:
      )
      site.update!(current_release: release)

      yield({ site:, person:, grant:, release:, json: })
    ensure
      ENV["SHORTBREAD_BLOB_ROOT"] = previous_root
    end
  end
end
