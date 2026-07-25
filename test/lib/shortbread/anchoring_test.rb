# frozen_string_literal: true

require "test_helper"

class AnchoringTest < ActiveSupport::TestCase
  DOCUMENT = <<~TEXT.strip
    Deploys are gated on review.
    Every change ships behind a flag.
    Retries are capped at three attempts.
  TEXT

  test "capture records the quote, both context sides, and the structural position" do
    anchor = capture_quote(DOCUMENT, "ships behind a flag")

    assert_equal "ships behind a flag", anchor.quote
    assert_equal DOCUMENT.index("ships behind a flag"), anchor.start_offset
    assert anchor.prefix.end_with?("Every change ")
    assert anchor.suffix.start_with?(".")
    assert_equal 1, anchor.block_index
  end

  test "an unchanged document resolves exact at full confidence" do
    anchor = capture_quote(DOCUMENT, "Retries are capped")
    resolution = Shortbread::Anchoring.resolve(anchor, DOCUMENT)

    assert_equal :exact, resolution.status
    assert_equal DOCUMENT.index("Retries are capped"), resolution.start_offset
    assert_in_delta 1.0, resolution.confidence, 0.001
  end

  test "an edit to an earlier passage shifts the anchor and resolves moved" do
    anchor = capture_quote(DOCUMENT, "Retries are capped at three attempts")
    edited = DOCUMENT.sub("Deploys are gated on review.", "Deploys are gated on review by two people.")

    resolution = Shortbread::Anchoring.resolve(anchor, edited)

    assert_equal :moved, resolution.status
    assert_equal edited.index("Retries are capped at three attempts"), resolution.start_offset
    assert_equal "Retries are capped at three attempts", edited[resolution.start_offset...resolution.end_offset]
  end

  # The defect this product exists to avoid: the prototype's first cut silently relocated a
  # Comment from deleted text onto an identical sentence elsewhere, reporting `moved` at 0.50.
  test "a Comment on deleted text orphans rather than relocating onto an identical string elsewhere" do
    document = <<~TEXT.strip
      Section one.
      The build must stay green.
      Section two.
      The build must stay green.
      Section three.
    TEXT

    anchor = capture_quote(document, "The build must stay green", occurrence: 1)
    without_anchored_text = document.sub("Section two.\nThe build must stay green.\n", "Section two.\n")

    resolution = Shortbread::Anchoring.resolve(anchor, without_anchored_text)

    assert_equal :orphaned, resolution.status,
      "a deleted Comment was relocated onto a different section's identical sentence"
    assert_nil resolution.start_offset
    assert_in_delta 0.0, resolution.confidence, 0.001
  end

  test "a quote that no longer appears at all is orphaned" do
    anchor = capture_quote(DOCUMENT, "ships behind a flag")
    rewritten = DOCUMENT.sub("ships behind a flag", "ships behind a toggle")

    resolution = Shortbread::Anchoring.resolve(anchor, rewritten)

    assert_equal :orphaned, resolution.status
    assert_nil resolution.start_offset
  end

  test "indistinguishable candidates resolve ambiguous rather than guessing" do
    # Repeats within a single block, so context scoring ties and the structural tie-break cannot
    # separate them either. The recorded offset no longer holds the quote.
    document = "go go go go and stop."
    anchor = Shortbread::Anchoring.capture(
      source: document, start_offset: 3, length: 2, release_number: 1, path: "index.html"
    )
    relocated = "Preface line.\ngo go go and stop."

    resolution = Shortbread::Anchoring.resolve(anchor, relocated)

    assert_includes %i[ambiguous orphaned], resolution.status,
      "indistinguishable candidates were resolved to a guess"
    assert_nil resolution.start_offset
    assert_in_delta 0.0, resolution.confidence, 0.001
  end

  test "a repeated string is distinguished by its surrounding context" do
    document = <<~TEXT.strip
      Alpha notes. The build must stay green. Alpha ends.
      Beta notes. The build must stay green. Beta ends.
    TEXT

    anchor = capture_quote(document, "The build must stay green", occurrence: 1)
    shifted = document.sub("Alpha notes.", "Alpha notes, revised for clarity.")

    resolution = Shortbread::Anchoring.resolve(anchor, shifted)

    assert_includes %i[exact moved], resolution.status
    assert_equal shifted.index("Beta notes."), find_containing_line_start(shifted, resolution.start_offset),
      "context disambiguation chose the wrong occurrence"
  end

  test "offsets are counted in Unicode code points so an astral character does not desync them" do
    document = "Ship 😀 it.\nThe build must stay green."
    anchor = capture_quote(document, "The build must stay green")

    assert_equal document.index("The build must stay green"), anchor.start_offset
    assert_equal "The build must stay green",
      document[anchor.start_offset, anchor.quote.length]

    resolution = Shortbread::Anchoring.resolve(anchor, document)
    assert_equal :exact, resolution.status
  end

  test "an empty quote is orphaned rather than matching everywhere" do
    anchor = Shortbread::Anchoring.capture(
      source: DOCUMENT, start_offset: 0, length: 0, release_number: 1, path: "index.html"
    )

    assert_equal :orphaned, Shortbread::Anchoring.resolve(anchor, DOCUMENT).status
  end

  private

  def capture_quote(source, quote, occurrence: 0)
    start_offset = nth_index(source, quote, occurrence)
    Shortbread::Anchoring.capture(
      source:, start_offset:, length: quote.length, release_number: 1, path: "index.html"
    )
  end

  def nth_index(source, quote, occurrence)
    offset = source.index(quote)
    occurrence.times { offset = source.index(quote, offset + 1) }
    offset
  end

  def find_containing_line_start(source, offset)
    return nil unless offset

    source.rindex("\n", offset).then { |newline| newline ? newline + 1 : 0 }
  end
end
