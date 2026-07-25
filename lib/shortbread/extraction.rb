# frozen_string_literal: true

module Shortbread
  # Visible text of a document, plus the map back to the bytes it came from. Anchors target this
  # text rather than source bytes, so markup changes that do not change what a reader sees leave
  # the Anchor undisturbed.
  #
  # Visibility is decided by TAG NAME ONLY. CSS is never consulted, so `display:none` text is
  # extracted. That is deliberate: the TypeScript twin walks the DOM under the same rule, and it
  # is agreement between the two that keeps client and server offsets in lockstep. An extractor
  # that consulted CSS — `innerText`, `getClientRects` — would silently break server-side
  # verification for every Anchor after a hidden element.
  module Extraction
    Extracted = Data.define(:text, :map)

    INVISIBLE = %w[script style head title meta link].freeze

    BLOCK = %w[
      p div h1 h2 h3 h4 h5 h6 li tr br hr section article header footer pre blockquote
      table thead tbody td th ul ol
    ].freeze

    ENTITIES = {
      "&amp;" => "&", "&lt;" => "<", "&gt;" => ">", "&quot;" => '"',
      "&#39;" => "'", "&apos;" => "'", "&nbsp;" => " ", "&mdash;" => "—", "&hellip;" => "…"
    }.freeze

    MAX_ENTITY_LENGTH = 10

    module_function

    # The visible text of one Manifest Entry, read through the Blob store's verification so the
    # bytes an Anchor is checked against are provably the bytes the Release was published with.
    # Returns nil when the Blob cannot be read, leaving the caller to decide what that means.
    def for_entry(entry, blob_store:)
      io = blob_store.open_verified(
        storage_key: entry.blob.storage_key,
        sha256: entry.blob.sha256,
        byte_size: entry.byte_size
      )
      from_html(io.read.force_encoding(Encoding::UTF_8))
    rescue BlobStore::ContentMismatch, BlobStore::StorageFailure
      nil
    ensure
      io&.close
    end

    # Where in the original bytes a text offset came from, so an Anchor resolved in text space can
    # be pointed back at the content-addressed Blob.
    def source_offset(extracted, text_offset)
      extracted.map[text_offset]
    end

    def from_html(html)
      state = { text: +"", map: [], pre_depth: 0, skip_until: nil }
      index = 0

      while index < html.length
        if html[index] == "<"
          close = html.index(">", index)
          break unless close

          apply_tag(state, html[(index + 1)...close].to_s, index)
          index = close + 1
          next
        end

        index = state[:skip_until] ? index + 1 : append_character(state, html, index)
      end

      trimmed(state)
    end

    def apply_tag(state, tag, index)
      closing = tag.start_with?("/")
      name = tag[%r{\A/?\s*([a-zA-Z0-9]+)}, 1]&.downcase

      if state[:skip_until]
        state[:skip_until] = nil if closing && name == state[:skip_until]
        return
      end

      if INVISIBLE.include?(name) && !closing
        state[:skip_until] = name unless tag.end_with?("/")
        return
      end

      if name == "pre"
        state[:pre_depth] += closing ? -1 : 1
        state[:pre_depth] = 0 if state[:pre_depth].negative?
      end

      # Both opening AND closing block tags break. Breaking only on entering an element lets the
      # whitespace after `</h1>` survive as a space and desyncs every subsequent offset.
      break_block(state, index) if BLOCK.include?(name)
    end

    def break_block(state, index)
      return if state[:text].empty? || state[:text].end_with?("\n")

      # A block break absorbs the collapsed space before it. Whitespace between a word and the end
      # of its block is not visible to a reader, so leaving it would make a reformatted document
      # extract differently from a minified one and shift every offset after the break.
      if state[:text].end_with?(" ")
        state[:text].chop!
        state[:map].pop
      end

      state[:text] << "\n"
      state[:map] << index
    end

    def append_character(state, html, index)
      character = html[index]

      if character == "&"
        semicolon = html.index(";", index)
        if semicolon && semicolon - index <= MAX_ENTITY_LENGTH
          decoded = ENTITIES[html[index..semicolon]]
          if decoded
            decoded.each_char { state[:map] << index }
            state[:text] << decoded
            return semicolon + 1
          end
        end
      end

      if character.match?(/\s/)
        append_whitespace(state, character, index)
        return index + 1
      end

      state[:text] << character
      state[:map] << index
      index + 1
    end

    # Runs of whitespace collapse to a single space the way a browser renders them — except
    # inside <pre>, where whitespace is content.
    def append_whitespace(state, character, index)
      if state[:pre_depth].positive?
        state[:text] << character
        state[:map] << index
      elsif !(state[:text].empty? || state[:text].end_with?(" ", "\n"))
        state[:text] << " "
        state[:map] << index
      end
    end

    # Trim text and map together — stripping only the text desyncs every offset after the
    # leading whitespace, which looks exactly like anchor drift.
    def trimmed(state)
      text = state[:text]
      leading = text[/\A\s*/].length
      trailing = text[/\s*\z/].length
      keep = text.length - leading - trailing
      keep = 0 if keep.negative?

      Extracted.new(text: text[leading, keep] || "", map: state[:map][leading, keep] || [])
    end
  end
end
