# frozen_string_literal: true

module Shortbread
  # Resolution of a captured Anchor against the visible text of one immutable (Release, path).
  #
  # Offsets are Unicode code points, which is what Ruby's String operations count natively. The
  # TypeScript twin converts from UTF-16 code units into this unit at its boundary: the server
  # verifies Anchors against stored bytes, so the unit the server computes natively is canonical.
  #
  # There is deliberately no carry-forward. Anchors are Release-scoped and immutable; continuity
  # across a republish is presented by the comparison view, never by re-pointing an Anchor.
  module Anchoring
    CONTEXT_LEN = 32
    STATUSES = %i[exact moved ambiguous orphaned].freeze

    Anchor = Struct.new(
      :release_number, :path, :quote, :prefix, :suffix, :start_offset, :block_index, :block_offset,
      keyword_init: true
    )

    Resolution = Struct.new(
      :status, :start_offset, :end_offset, :confidence, :note, :candidates,
      keyword_init: true
    )

    module_function

    def capture(source:, start_offset:, length:, release_number:, path:)
      quote = source[start_offset, length]
      prefix = source[[ start_offset - CONTEXT_LEN, 0 ].max...start_offset] || ""
      suffix = source[(start_offset + length), CONTEXT_LEN] || ""
      block_index, block_offset = block_position(source, start_offset)

      Anchor.new(
        release_number:, path:, quote:, prefix:, suffix:, start_offset:, block_index:, block_offset:
      )
    end

    # Ordered tiers, each reporting how it succeeded. Failure is a first-class :orphaned result,
    # never a dropped highlight and never a guess.
    def resolve(anchor, source)
      return orphaned("quote is empty") if anchor.quote.to_s.empty?

      occurrences = all_occurrences(source, anchor.quote)
      return orphaned("quote no longer appears in this document") if occurrences.empty?

      exact = resolve_at_recorded_offset(anchor, source, occurrences)
      return exact if exact

      resolve_by_context(anchor, source, occurrences)
    end

    # Tier 1 — the quote still sits at the recorded offset with both context sides agreeing.
    # Offset alone is not enough: if another occurrence scores just as well, the recorded offset
    # is a coin-flip that happened to be right once, so only claim :exact when it is uniquely best.
    def resolve_at_recorded_offset(anchor, source, occurrences)
      return nil unless occurrences.include?(anchor.start_offset)
      return nil unless context_score(anchor, source, anchor.start_offset) == 2

      rivals = (occurrences - [ anchor.start_offset ]).select { |offset| context_score(anchor, source, offset) == 2 }
      unless rivals.empty? || structural_tiebreak(anchor, source, [ anchor.start_offset ] + rivals) == [ anchor.start_offset ]
        return nil
      end

      Resolution.new(
        status: :exact, start_offset: anchor.start_offset,
        end_offset: anchor.start_offset + anchor.quote.length, confidence: 1.0,
        note: "offset and both context sides match, uniquely", candidates: occurrences
      )
    end

    # Tier 2 — score every occurrence by context agreement, break ties structurally. Handles both
    # "an earlier paragraph was edited" and "the string appears five times".
    def resolve_by_context(anchor, source, occurrences)
      scored = occurrences.map { |offset| [ offset, context_score(anchor, source, offset) ] }
      best = scored.map(&:last).max
      winners = scored.select { |(_, score)| score == best }.map(&:first)
      winners = structural_tiebreak(anchor, source, winners) if winners.length > 1

      if winners.length > 1
        # Same quote, same context, no structural separation. Proximity is only a legitimate
        # tie-break when the document still corroborates the anchor's own offset.
        return ambiguous(winners, best) unless winners.include?(anchor.start_offset)

        winners = [ anchor.start_offset ]
      end

      offset = winners.first

      # A surviving occurrence is not evidence that it is the SAME occurrence. With no context
      # agreement and the text moved, the reviewer's sentence may have been deleted and this is a
      # different instance of the same string. A Comment parked in a tray is recoverable; one
      # silently attached to the wrong paragraph is not.
      if best.zero? && offset != anchor.start_offset
        return Resolution.new(
          status: :orphaned, start_offset: nil, end_offset: nil, confidence: 0.0,
          candidates: occurrences,
          note: "quote still present but all surrounding context changed — cannot confirm identity"
        )
      end

      placed(anchor, offset, best, occurrences)
    end

    def placed(anchor, offset, context_sides, occurrences)
      confidence = 0.5 + (context_sides * 0.25)
      end_offset = offset + anchor.quote.length

      if offset == anchor.start_offset && context_sides.positive?
        Resolution.new(
          status: :exact, start_offset: offset, end_offset:, confidence:,
          note: "offset unchanged, #{context_sides}/2 context sides match", candidates: occurrences
        )
      else
        Resolution.new(
          status: :moved, start_offset: offset, end_offset:, confidence:,
          note: "text found at #{offset} (was #{anchor.start_offset}), #{context_sides}/2 context sides match",
          candidates: occurrences
        )
      end
    end

    def all_occurrences(source, quote)
      offsets = []
      offset = source.index(quote)
      while offset
        offsets << offset
        offset = source.index(quote, offset + 1)
      end
      offsets
    end

    # 0, 1, or 2 — how many context sides still agree at this candidate offset.
    def context_score(anchor, source, offset)
      score = 0

      unless anchor.prefix.empty?
        actual = source[[ offset - anchor.prefix.length, 0 ].max...offset] || ""
        score += 1 if actual == anchor.prefix
      end

      unless anchor.suffix.empty?
        actual = source[(offset + anchor.quote.length), anchor.suffix.length] || ""
        score += 1 if actual == anchor.suffix
      end

      score
    end

    def blocks(source)
      found = []
      offset = 0
      source.split(/(\n[ \t]*\n|\n)/).each do |chunk|
        found << [ offset, chunk ] unless chunk.strip.empty?
        offset += chunk.length
      end
      found
    end

    def block_position(source, offset)
      blocks(source).each_with_index do |(start, text), index|
        return [ index, offset - start ] if offset >= start && offset < start + text.length
      end
      [ nil, nil ]
    end

    def structural_tiebreak(anchor, source, offsets)
      return offsets if anchor.block_index.nil?

      same_block = offsets.select { |offset| block_position(source, offset).first == anchor.block_index }
      same_block.empty? ? offsets : same_block
    end

    def ambiguous(winners, context_sides)
      Resolution.new(
        status: :ambiguous, start_offset: nil, end_offset: nil, confidence: 0.0, candidates: winners,
        note: "#{winners.length} equally-good candidates (context #{context_sides}/2), no way to choose"
      )
    end

    def orphaned(note)
      Resolution.new(
        status: :orphaned, start_offset: nil, end_offset: nil, confidence: 0.0, note:, candidates: []
      )
    end
  end
end
