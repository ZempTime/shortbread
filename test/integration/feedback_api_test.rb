# frozen_string_literal: true

require "test_helper"

require "digest"
require "stringio"
require "tmpdir"

class FeedbackApiTest < ActionDispatch::IntegrationTest
  DOCUMENT = "<h1>Deploy notes</h1><p>Every change ships behind a flag.</p>"
  QUOTE = "ships behind a flag"

  test "a Producer pulls the Feedback Thread with Release, path, quote, placement, body, and Person" do
    with_reviewable_site do |context|
      comment = create_comment(context, body: "Which flag is this?")

      get "/api/v1/sites/#{context.fetch(:site).slug}/feedback",
        headers: producer_headers

      assert_response :ok
      payload = JSON.parse(response.body)
      assert_equal context.fetch(:site).slug, payload.dig("site", "slug")

      pulled = payload.fetch("comments").sole
      assert_equal comment.id, pulled.fetch("id")
      assert_equal 1, pulled.fetch("release_number")
      assert_equal "index.html", pulled.fetch("path")
      assert_equal QUOTE, pulled.fetch("quote")
      assert_equal "exact", pulled.fetch("placement")
      assert_equal "Which flag is this?", pulled.fetch("body")
      assert_equal "Avery", pulled.fetch("person")
      assert pulled.fetch("created_at").present?
    end
  end

  test "a Comment whose anchored text no longer resolves is pulled as orphaned with its quote" do
    with_reviewable_site do |context|
      Comment.create!(
        site: context.fetch(:site), release: context.fetch(:release),
        person: context.fetch(:person), grant: context.fetch(:grant),
        body: "About a passage that is gone.", path: "index.html",
        quote: "ships behind a rocket", prefix: "Every change ", suffix: ".",
        start_offset: 0, block_index: 0, block_offset: 0
      )

      get "/api/v1/sites/#{context.fetch(:site).slug}/feedback", headers: producer_headers

      assert_response :ok
      pulled = JSON.parse(response.body).fetch("comments").sole
      assert_equal "orphaned", pulled.fetch("placement")
      assert_equal "ships behind a rocket", pulled.fetch("quote"),
        "an orphaned Comment lost the quote the reviewer actually selected"
    end
  end

  test "a Site-level Comment with no selection is pulled without an Anchor" do
    with_reviewable_site do |context|
      Comment.create!(
        site: context.fetch(:site), release: context.fetch(:release),
        person: context.fetch(:person), grant: context.fetch(:grant),
        body: "A remark about the whole document."
      )

      get "/api/v1/sites/#{context.fetch(:site).slug}/feedback", headers: producer_headers

      assert_response :ok
      pulled = JSON.parse(response.body).fetch("comments").sole
      assert_nil pulled.fetch("quote")
      assert_nil pulled.fetch("path")
      assert_equal "unanchored", pulled.fetch("placement")
    end
  end

  test "Comments are returned chronologically across Releases" do
    with_reviewable_site do |context|
      first = create_comment(context, body: "First remark.")
      second = create_comment(context, body: "Second remark.")

      get "/api/v1/sites/#{context.fetch(:site).slug}/feedback", headers: producer_headers

      assert_response :ok
      ids = JSON.parse(response.body).fetch("comments").map { |comment| comment.fetch("id") }
      assert_equal [ first.id, second.id ], ids
    end
  end

  test "feedback requires Producer authentication" do
    with_reviewable_site do |context|
      create_comment(context, body: "Private.")

      get "/api/v1/sites/#{context.fetch(:site).slug}/feedback"

      assert_response :unauthorized
      assert_not_includes response.body, "Private."
    end
  end

  test "an unknown Site is not found" do
    with_reviewable_site do |_context|
      get "/api/v1/sites/no-such-site/feedback", headers: producer_headers

      assert_response :not_found
    end
  end

  private

  def producer_headers
    { "Authorization" => "Bearer #{ENV.fetch("SHORTBREAD_BOOTSTRAP_TOKEN")}" }
  end

  def create_comment(context, body:)
    text = Shortbread::Extraction.from_html(DOCUMENT).text
    offset = text.index(QUOTE)

    Comment.create!(
      site: context.fetch(:site), release: context.fetch(:release),
      person: context.fetch(:person), grant: context.fetch(:grant),
      body:, path: "index.html", quote: QUOTE,
      prefix: text[[ offset - Shortbread::Anchoring::CONTEXT_LEN, 0 ].max...offset].to_s,
      suffix: text[(offset + QUOTE.length), Shortbread::Anchoring::CONTEXT_LEN].to_s,
      start_offset: offset, block_index: 1, block_offset: 13
    )
  end

  def with_reviewable_site(slug: "first-site")
    Dir.mktmpdir("shortbread-feedback-api") do |root|
      previous_root = ENV["SHORTBREAD_BLOB_ROOT"]
      previous_token = ENV["SHORTBREAD_BOOTSTRAP_TOKEN"]
      ENV["SHORTBREAD_BLOB_ROOT"] = root
      ENV["SHORTBREAD_BOOTSTRAP_TOKEN"] = "producer-token-#{SecureRandom.hex(8)}"

      site = Site.create!(slug:, name: "First Site")
      person = Person.create!(first_name: "Avery")
      grant = Grant.create!(site:, person:)
      digest = Digest::SHA256.hexdigest(DOCUMENT)
      storage_key = LocalBlobStore.new.put_verified(
        io: StringIO.new(DOCUMENT), sha256: digest, byte_size: DOCUMENT.bytesize
      )
      blob = Blob.create!(sha256: digest, byte_size: DOCUMENT.bytesize, storage_key:)
      release = assemble_test_release!(
        site:, number: 1, manifest_sha256: Digest::SHA256.hexdigest("manifest"),
        finalized_at: Time.current,
        entries: [ {
          blob:, path: "index.html", byte_size: DOCUMENT.bytesize,
          content_type: "text/html", offline_policy: "required"
        } ]
      )
      site.update!(current_release: release)

      host! "localhost"
      yield({ site:, person:, grant:, release: })
    ensure
      ENV["SHORTBREAD_BLOB_ROOT"] = previous_root
      ENV["SHORTBREAD_BOOTSTRAP_TOKEN"] = previous_token
    end
  end
end
