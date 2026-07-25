# frozen_string_literal: true

require "test_helper"

require "json"

# The Ruby half of the shared conformance matrix. Its TypeScript twin at
# test/frontend/anchoring.test.ts drives the SAME fixture file and asserts the same expectations,
# so a disagreement between the two implementations fails a suite rather than silently producing
# Anchors the server cannot verify.
class AnchoringConformanceTest < ActiveSupport::TestCase
  FIXTURES = JSON.parse(
    Rails.root.join("test/frontend/conformance_fixtures.json").read,
    symbolize_names: true
  ).freeze

  test "extraction matches the shared fixture text for every case" do
    FIXTURES.fetch(:extraction).each do |fixture|
      extracted = Shortbread::Extraction.from_html(fixture.fetch(:html))

      assert_equal fixture.fetch(:text), extracted.text, fixture.fetch(:name)
      assert_equal extracted.text.length, extracted.map.length,
        "#{fixture.fetch(:name)}: offset map desynced from the text"
    end
  end

  test "resolution reports the shared fixture status for every case" do
    FIXTURES.fetch(:resolution).each do |fixture|
      anchor = anchor_for(fixture)
      resolution = Shortbread::Anchoring.resolve(anchor, fixture.fetch(:republished))

      assert_equal fixture.fetch(:status).to_sym, resolution.status, fixture.fetch(:name)
    end
  end

  test "a resolved offset always points at the anchored quote" do
    FIXTURES.fetch(:resolution).each do |fixture|
      anchor = anchor_for(fixture)
      resolution = Shortbread::Anchoring.resolve(anchor, fixture.fetch(:republished))
      next unless resolution.start_offset

      republished = fixture.fetch(:republished)
      assert_equal anchor.quote, republished[resolution.start_offset...resolution.end_offset],
        "#{fixture.fetch(:name)}: resolved offset does not hold the quote"
    end
  end

  # The PRD names these as minimum matrix coverage: markup churn must not disturb an Anchor,
  # because the Anchor targets extracted visible text rather than the bytes around it.
  test "markup changes that leave visible text alone do not disturb the anchor" do
    FIXTURES.fetch(:html_resolution).each do |fixture|
      text = Shortbread::Extraction.from_html(fixture.fetch(:html)).text
      quote = fixture.fetch(:quote)
      anchor = Shortbread::Anchoring.capture(
        source: text, start_offset: nth_index(text, quote, fixture.fetch(:occurrence)),
        length: quote.length, release_number: 1, path: "index.html"
      )
      republished = Shortbread::Extraction.from_html(fixture.fetch(:republished_html)).text

      resolution = Shortbread::Anchoring.resolve(anchor, republished)

      assert_equal fixture.fetch(:status).to_sym, resolution.status, fixture.fetch(:name)
    end
  end

  test "overlapping Anchors on the same sentence each resolve independently" do
    FIXTURES.fetch(:overlapping).each do |fixture|
      source = fixture.fetch(:source)
      republished = fixture.fetch(:republished)

      fixture.fetch(:anchors).each do |expected|
        quote = expected.fetch(:quote)
        anchor = Shortbread::Anchoring.capture(
          source:, start_offset: nth_index(source, quote, expected.fetch(:occurrence)),
          length: quote.length, release_number: 1, path: "index.html"
        )

        resolution = Shortbread::Anchoring.resolve(anchor, republished)

        assert_equal expected.fetch(:status).to_sym, resolution.status,
          "#{fixture.fetch(:name)}: #{quote}"
        assert_equal quote, republished[resolution.start_offset...resolution.end_offset],
          "#{fixture.fetch(:name)}: #{quote} resolved onto different text"
      end
    end
  end

  private

  def anchor_for(fixture)
    source = fixture.fetch(:source)
    quote = fixture.fetch(:quote)
    start_offset = nth_index(source, quote, fixture.fetch(:occurrence))

    Shortbread::Anchoring.capture(
      source:, start_offset:, length: quote.length, release_number: 1, path: "index.html"
    )
  end

  def nth_index(source, quote, occurrence)
    offset = source.index(quote)
    occurrence.times { offset = source.index(quote, offset + 1) }
    offset
  end
end
