# frozen_string_literal: true

require "test_helper"

require "digest"

class CommentTest < ActiveSupport::TestCase
  test "a Comment persists its Anchor composite against the Release and path it was captured on" do
    context = commentable_site

    comment = Comment.create!(
      site: context.fetch(:site),
      release: context.fetch(:release),
      person: context.fetch(:person),
      grant: context.fetch(:grant),
      path: "index.html",
      body: "This gate is the one that keeps biting us.",
      quote: "Deploys are gated on review",
      prefix: "",
      suffix: ". Every change ships",
      start_offset: 0,
      block_index: 0,
      block_offset: 0
    )

    assert comment.persisted?
    assert_equal "Deploys are gated on review", comment.quote
    assert_equal 0, comment.start_offset
    assert_equal context.fetch(:release).id, comment.release_id
    assert comment.anchored?
  end

  # #69 adds Site-level Comments with no selection. Modelling the Anchor as optional now avoids a
  # second migration then.
  test "a Comment without an Anchor is valid, so a Site-level remark needs no selection" do
    context = commentable_site

    comment = Comment.create!(
      site: context.fetch(:site),
      release: context.fetch(:release),
      person: context.fetch(:person),
      grant: context.fetch(:grant),
      body: "General thought about the whole document."
    )

    assert comment.persisted?
    assert_not comment.anchored?
    assert_nil comment.quote
    assert_nil comment.start_offset
    assert_nil comment.path
  end

  test "an Anchor is all-or-nothing rather than partially recorded" do
    context = commentable_site

    partial = Comment.new(
      site: context.fetch(:site),
      release: context.fetch(:release),
      person: context.fetch(:person),
      grant: context.fetch(:grant),
      body: "Half an anchor.",
      quote: "Deploys are gated on review"
    )

    assert_not partial.valid?
    assert_includes partial.errors.attribute_names, :start_offset
  end

  test "a Comment requires a body" do
    context = commentable_site

    comment = Comment.new(
      site: context.fetch(:site),
      release: context.fetch(:release),
      person: context.fetch(:person),
      grant: context.fetch(:grant),
      body: "   "
    )

    assert_not comment.valid?
    assert_includes comment.errors.attribute_names, :body
  end

  test "Comments are append-only: the database refuses an update" do
    context = commentable_site
    comment = Comment.create!(
      site: context.fetch(:site),
      release: context.fetch(:release),
      person: context.fetch(:person),
      grant: context.fetch(:grant),
      body: "Original wording."
    )

    assert_database_rejects(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(
        "UPDATE comments SET body = 'edited' WHERE id = #{comment.id}"
      )
    end

    assert_equal "Original wording.", comment.reload.body
  end

  test "a Comment survives revocation of the Grant that produced it, still attributed" do
    context = commentable_site
    comment = Comment.create!(
      site: context.fetch(:site),
      release: context.fetch(:release),
      person: context.fetch(:person),
      grant: context.fetch(:grant),
      body: "Left before access was revoked."
    )

    context.fetch(:grant).update!(revoked_at: Time.current)

    assert_equal context.fetch(:person).id, comment.reload.person_id
    assert_equal "Left before access was revoked.", comment.body
  end

  test "a Comment cannot point at a Release belonging to another Site" do
    context = commentable_site
    other = commentable_site(slug: "second-site", person_name: "Blair")

    crossed = Comment.new(
      site: context.fetch(:site),
      release: other.fetch(:release),
      person: context.fetch(:person),
      grant: context.fetch(:grant),
      body: "Wrong Site's Release."
    )

    assert_not crossed.valid?
    assert_includes crossed.errors.attribute_names, :release
    assert_database_rejects(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(<<~SQL)
        INSERT INTO comments (site_id, release_id, person_id, grant_id, body, created_at, updated_at)
        VALUES (#{context.fetch(:site).id}, #{other.fetch(:release).id},
                #{context.fetch(:person).id}, #{context.fetch(:grant).id}, 'bypass', NOW(), NOW())
      SQL
    end
  end

  private

  def assert_database_rejects(error_class, &)
    assert_raises(error_class) do
      ApplicationRecord.transaction(requires_new: true, &)
    end
  end

  def commentable_site(slug: "first-site", person_name: "Avery")
    site = Site.create!(slug:, name: "Site #{slug}")
    person = Person.create!(first_name: person_name)
    grant = Grant.create!(site:, person:)
    content = "<p>Deploys are gated on review. Every change ships behind a flag.</p>"
    digest = Digest::SHA256.hexdigest("#{slug}-#{content}")
    blob = Blob.create!(sha256: digest, byte_size: content.bytesize, storage_key: digest)
    release = assemble_test_release!(
      site:, number: 1, manifest_sha256: Digest::SHA256.hexdigest("manifest-#{slug}"),
      finalized_at: Time.current,
      entries: [ {
        blob:, path: "index.html", byte_size: content.bytesize,
        content_type: "text/html", offline_policy: "required"
      } ]
    )
    site.update!(current_release: release)

    { site:, person:, grant:, release:, blob: }
  end
end
