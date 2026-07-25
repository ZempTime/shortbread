# frozen_string_literal: true

# The Site's whole Feedback Thread: every Comment across every Release, chronological, each with
# its Anchor resolved against the Release it was left on.
#
# This is the browserless view. A Producer or agent receives enough context — Release, path,
# quote, placement — to locate what a Comment refers to without opening a browser, which is the
# same guarantee the review surface gives a Viewer.
class SiteFeedback
  def self.call(site:, blob_store: nil)
    new(site:, blob_store:).call
  end

  def initialize(site:, blob_store: nil)
    @site = site
    @blob_store = blob_store || Shortbread::BlobStores.build
  end

  def call
    comments = site.comments.includes(:person, :release).chronological.to_a
    return [] if comments.empty?

    placements = resolve_by_release(comments)
    comments.map { |comment| payload(comment, placements.fetch(comment.id)) }
  end

  private

  attr_reader :site, :blob_store

  # Grouped by Release so each Release's documents are read and extracted once, however many
  # Comments point at them.
  def resolve_by_release(comments)
    comments.group_by(&:release).each_with_object({}) do |(release, release_comments), found|
      placements = CommentPlacements.new(release:, blob_store:).call
      by_id = placements.index_by { |placement| placement.fetch(:id) }
      release_comments.each { |comment| found[comment.id] = by_id.fetch(comment.id) }
    end
  end

  def payload(comment, placement)
    {
      id: comment.id,
      release_number: comment.release.number,
      path: comment.path,
      quote: comment.quote,
      placement: placement.fetch(:placement),
      confidence: placement.fetch(:confidence),
      body: comment.body,
      person: comment.person.first_name,
      created_at: comment.created_at.iso8601(6)
    }
  end
end
