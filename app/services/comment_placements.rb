# frozen_string_literal: true

# Each Comment on a Release, with its Anchor resolved against that Release's stored bytes.
#
# Resolution is lazy and happens here rather than at publish time, so the same code answers both
# the review surface and a browserless CLI client. A Comment whose text cannot be confidently
# placed is reported with its original quote and an explicit placement, never dropped.
class CommentPlacements
  PLACEMENT_WITHOUT_ANCHOR = "unanchored"

  def self.call(release:, path: nil, blob_store: nil)
    new(release:, blob_store:).call(path:)
  end

  def initialize(release:, blob_store: nil)
    @release = release
    @blob_store = blob_store || Shortbread::BlobStores.build
    @extractions = {}
  end

  def call(path: nil)
    scope = release.comments.includes(:person).chronological
    scope = scope.where(path:) if path.present?

    scope.map { |comment| placement_for(comment) }
  end

  private

  attr_reader :release, :blob_store, :extractions

  def placement_for(comment)
    {
      id: comment.id,
      body: comment.body,
      person: comment.person.first_name,
      path: comment.path,
      quote: comment.quote,
      prefix: comment.prefix,
      suffix: comment.suffix,
      startOffset: comment.start_offset,
      blockIndex: comment.block_index,
      blockOffset: comment.block_offset,
      createdAt: comment.created_at.iso8601,
      **resolution_for(comment)
    }
  end

  def resolution_for(comment)
    return { placement: PLACEMENT_WITHOUT_ANCHOR, confidence: nil } unless comment.anchored?

    text = extracted_text(comment.path)
    return { placement: "orphaned", confidence: 0.0 } unless text

    resolution = Shortbread::Anchoring.resolve(comment.to_anchor, text)
    { placement: resolution.status.to_s, confidence: resolution.confidence }
  end

  def extracted_text(path)
    return nil unless path

    extractions.fetch(path) do
      extractions[path] = build_extraction(path)
    end
  end

  def build_extraction(path)
    entry = release.manifest_entries.includes(:blob).find_by(path:)
    return nil unless entry

    bytes = read_blob(entry)
    bytes && Shortbread::Extraction.from_html(bytes).text
  end

  def read_blob(entry)
    io = blob_store.open_verified(
      storage_key: entry.blob.storage_key,
      sha256: entry.blob.sha256,
      byte_size: entry.byte_size
    )
    io.read.force_encoding(Encoding::UTF_8)
  rescue Shortbread::BlobStore::ContentMismatch, Shortbread::BlobStore::StorageFailure
    nil
  ensure
    io&.close
  end
end
