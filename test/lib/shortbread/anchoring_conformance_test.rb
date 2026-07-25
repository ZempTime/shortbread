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
