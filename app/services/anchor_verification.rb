# frozen_string_literal: true

# Turns an untrusted client Anchor payload into one verified against the Release's stored bytes.
#
# The Release resolves to exact, unchanging bytes, so the server never has to trust a client
# offset: it extracts the document itself and confirms the claimed quote really sits at the
# claimed offset. Everything stored on the Comment is re-derived here — prefix, suffix, and the
# structural position come from the server's own extraction, not from the payload.
class AnchorVerification
  Verified = Data.define(:path, :quote, :prefix, :suffix, :start_offset, :block_index, :block_offset)

  class Rejected < StandardError
    MESSAGE = "anchor rejected"

    def initialize = super(MESSAGE)
  end

  def self.call(release:, payload:, blob_store: nil)
    new(release:, blob_store:).call(payload)
  end

  def initialize(release:, blob_store: nil)
    @release = release
    @blob_store = blob_store || Shortbread::BlobStores.build
  end

  def call(payload)
    path = payload[:path]
    quote = payload[:quote]
    start_offset = integer_offset(payload[:start_offset])
    reject! unless path.is_a?(String) && quote.is_a?(String) && quote.present? && start_offset

    entry = manifest_entry(path)
    reject! unless entry

    text = extracted_text(entry)
    reject! unless text[start_offset, quote.length] == quote

    build(path:, quote:, start_offset:, text:)
  end

  private

  attr_reader :release, :blob_store

  def build(path:, quote:, start_offset:, text:)
    block_index, block_offset = Shortbread::Anchoring.block_position(text, start_offset)

    Verified.new(
      path:, quote:, start_offset:, block_index:, block_offset:,
      prefix: text[[ start_offset - Shortbread::Anchoring::CONTEXT_LEN, 0 ].max...start_offset].to_s,
      suffix: text[(start_offset + quote.length), Shortbread::Anchoring::CONTEXT_LEN].to_s
    )
  end

  def manifest_entry(path)
    return nil unless Shortbread::ManifestPaths.valid?(path)

    release.manifest_entries.includes(:blob).find_by(path:)
  end

  def extracted_text(entry)
    Shortbread::Extraction.from_html(read_blob(entry)).text
  end

  def read_blob(entry)
    io = blob_store.open_verified(
      storage_key: entry.blob.storage_key,
      sha256: entry.blob.sha256,
      byte_size: entry.byte_size
    )
    io.read.force_encoding(Encoding::UTF_8)
  rescue Shortbread::BlobStore::ContentMismatch, Shortbread::BlobStore::StorageFailure
    reject!
  ensure
    io&.close
  end

  def integer_offset(value)
    offset = Integer(value, exception: false)
    offset if offset&.>=(0)
  end

  def reject! = raise(Rejected)
end
