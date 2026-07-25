# frozen_string_literal: true

require "test_helper"

require "digest"
require "stringio"
require "tmpdir"

class CommentCreationTest < ActionDispatch::IntegrationTest
  DOCUMENT = "<h1>Deploy notes</h1><p>Every change ships behind a flag.</p>"
  QUOTE = "ships behind a flag"

  test "a Viewer posts a Comment on selected text and it persists with its Anchor" do
    with_reviewable_site do |context|
      as_viewer(context)

      assert_difference -> { Comment.count }, 1 do
        post "/_shortbread/comments", params: anchor_payload(body: "This flag is the one that bites."), as: :json
      end

      assert_response :created

      comment = Comment.order(:id).last
      assert_equal "This flag is the one that bites.", comment.body
      assert_equal QUOTE, comment.quote
      assert_equal "index.html", comment.path
      assert_equal context.fetch(:release).id, comment.release_id
      assert_equal context.fetch(:person).id, comment.person_id
      assert_equal extracted_text.index(QUOTE), comment.start_offset
      assert comment.anchored?
    end
  end

  # The server holds the Release's exact bytes, so it never has to trust a client offset.
  test "an Anchor whose quote does not match the stored bytes at the claimed offset is rejected" do
    with_reviewable_site do |context|
      as_viewer(context)

      assert_no_difference -> { Comment.count } do
        post "/_shortbread/comments",
          params: anchor_payload(body: "Forged.", quote: "ships behind a rocket"),
          as: :json
      end

      assert_response :unprocessable_content
      assert_no_difference -> { Comment.count } do
        post "/_shortbread/comments",
          params: anchor_payload(body: "Shifted.", start_offset: extracted_text.index(QUOTE) + 5),
          as: :json
      end

      assert_response :unprocessable_content
    end
  end

  test "an Anchor claiming a path absent from the Release Manifest is rejected" do
    with_reviewable_site do |context|
      as_viewer(context)

      assert_no_difference -> { Comment.count } do
        post "/_shortbread/comments",
          params: anchor_payload(body: "Nowhere.", path: "not-in-manifest.html"),
          as: :json
      end

      assert_response :unprocessable_content
    end
  end

  test "an offset beyond the end of the document is rejected rather than raising" do
    with_reviewable_site do |context|
      as_viewer(context)

      assert_no_difference -> { Comment.count } do
        post "/_shortbread/comments",
          params: anchor_payload(body: "Past the end.", start_offset: 10_000),
          as: :json
      end

      assert_response :unprocessable_content
    end
  end

  test "a Comment requires a valid Grant-backed Site session" do
    with_reviewable_site do |context|
      assert_no_difference -> { Comment.count } do
        post "/_shortbread/comments", params: anchor_payload(body: "Uninvited."), as: :json
      end
      assert_response :not_found

      as_viewer(context)
      context.fetch(:grant).update!(revoked_at: Time.current)

      assert_no_difference -> { Comment.count } do
        post "/_shortbread/comments", params: anchor_payload(body: "Revoked."), as: :json
      end
      assert_response :not_found
    end
  end

  test "a Site-level Comment with no selection is accepted" do
    with_reviewable_site do |context|
      as_viewer(context)

      assert_difference -> { Comment.count }, 1 do
        post "/_shortbread/comments", params: { body: "A general remark." }, as: :json
      end

      assert_response :created
      comment = Comment.order(:id).last
      assert_not comment.anchored?
      assert_equal "A general remark.", comment.body
    end
  end

  test "a Comment with an empty body is rejected" do
    with_reviewable_site do |context|
      as_viewer(context)

      assert_no_difference -> { Comment.count } do
        post "/_shortbread/comments", params: anchor_payload(body: "   "), as: :json
      end

      assert_response :unprocessable_content
    end
  end

  test "neither the Comment body nor its quote is written to the logs" do
    with_reviewable_site do |context|
      as_viewer(context)
      secret_body = "SECRET_COMMENT_BODY_MARKER"
      logs = capture_rails_log do
        post "/_shortbread/comments", params: anchor_payload(body: secret_body), as: :json
      end

      assert_response :created
      assert_not_includes logs, secret_body, "the Comment body reached the logs"
      assert_not_includes logs, QUOTE, "the anchored quote reached the logs"
    end
  end

  private

  def extracted_text
    Shortbread::Extraction.from_html(DOCUMENT).text
  end

  def anchor_payload(body:, quote: QUOTE, path: "index.html", start_offset: nil)
    text = extracted_text
    offset = start_offset || text.index(QUOTE)

    {
      body:,
      path:,
      quote:,
      prefix: text[[ offset - Shortbread::Anchoring::CONTEXT_LEN, 0 ].max...offset].to_s,
      suffix: text[(offset + quote.length), Shortbread::Anchoring::CONTEXT_LEN].to_s,
      start_offset: offset
    }
  end

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

  def capture_rails_log
    original = Rails.logger
    buffer = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(buffer)
    yield
    buffer.string
  ensure
    Rails.logger = original
  end

  def with_reviewable_site(slug: "first-site")
    Dir.mktmpdir("shortbread-reviewable-site") do |root|
      previous_root = ENV["SHORTBREAD_BLOB_ROOT"]
      ENV["SHORTBREAD_BLOB_ROOT"] = root

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

      yield({ site:, person:, grant:, release:, blob: })
    ensure
      ENV["SHORTBREAD_BLOB_ROOT"] = previous_root
    end
  end
end
