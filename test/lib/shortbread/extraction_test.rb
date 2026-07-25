# frozen_string_literal: true

require "test_helper"

class ExtractionTest < ActiveSupport::TestCase
  test "visible text is extracted with whitespace collapsed the way a browser renders it" do
    extraction = Shortbread::Extraction.from_html(<<~HTML)
      <h1>Deploy   notes</h1>
      <p>Every change ships
      behind a flag.</p>
    HTML

    assert_equal "Deploy notes\nEvery change ships behind a flag.", extraction.text
  end

  # The correction the browser spike found: a linear scanner emits a block break on a CLOSING tag
  # as well as an opening one. A DOM walker that breaks only on ENTERING an element lets the
  # whitespace after </h1> survive as a space and desyncs every offset after it.
  test "a closing block tag breaks the text so trailing whitespace cannot survive as a space" do
    extraction = Shortbread::Extraction.from_html("<h1>Title</h1>\n  <p>Body</p>")

    assert_equal "Title\nBody", extraction.text
    assert_not_includes extraction.text, "Title ", "whitespace after a closing block tag survived"
  end

  test "invisible elements contribute no text" do
    extraction = Shortbread::Extraction.from_html(
      "<style>p { color: red }</style><script>var x = 1;</script><p>Visible</p>"
    )

    assert_equal "Visible", extraction.text
  end

  # Both extractors skip by tag name only and therefore emit CSS-hidden text. That is harmless
  # ONLY because both sides do it identically, keeping client and server offsets in lockstep.
  test "CSS-hidden text is extracted, because visibility is never consulted" do
    extraction = Shortbread::Extraction.from_html(
      "<p>Before</p><div style=\"display:none\">Hidden</div><p>After</p>"
    )

    assert_includes extraction.text, "Hidden",
      "a CSS-aware extractor would desync offsets against the server"
  end

  test "whitespace inside pre is content rather than collapsed" do
    extraction = Shortbread::Extraction.from_html("<pre>line one\n    indented</pre>")

    assert_includes extraction.text, "line one\n    indented"
  end

  test "entities decode to their character" do
    extraction = Shortbread::Extraction.from_html("<p>Tea &amp; toast &mdash; ready</p>")

    assert_equal "Tea & toast — ready", extraction.text
  end

  test "the offset map points every extracted character back at its source byte" do
    html = "<p>Alpha</p><p>Beta</p>"
    extraction = Shortbread::Extraction.from_html(html)

    offset = extraction.text.index("Beta")
    source_offset = Shortbread::Extraction.source_offset(extraction, offset)

    assert_equal "Beta", html[source_offset, 4]
  end

  test "the map stays in lockstep with the text when leading whitespace is trimmed" do
    html = "   \n  <p>Alpha</p>"
    extraction = Shortbread::Extraction.from_html(html)

    assert_equal "Alpha", extraction.text
    assert_equal extraction.text.length, extraction.map.length
    assert_equal "Alpha", html[Shortbread::Extraction.source_offset(extraction, 0), 5]
  end

  test "extraction and anchoring compose over the same document" do
    html = "<h1>Deploy notes</h1><p>Every change ships behind a flag.</p>"
    extraction = Shortbread::Extraction.from_html(html)
    quote = "ships behind a flag"
    anchor = Shortbread::Anchoring.capture(
      source: extraction.text, start_offset: extraction.text.index(quote), length: quote.length,
      release_number: 1, path: "index.html"
    )

    resolution = Shortbread::Anchoring.resolve(anchor, Shortbread::Extraction.from_html(html).text)

    assert_equal :exact, resolution.status
    assert_equal quote, extraction.text[resolution.start_offset...resolution.end_offset]
  end

  test "markup changes that leave visible text alone do not disturb the anchor" do
    original = "<p>Every change <em>ships</em> behind a flag.</p>"
    restyled = "<p class=\"lede\">Every change <strong>ships</strong> behind a flag.</p>"
    text = Shortbread::Extraction.from_html(original).text
    quote = "ships behind a flag"
    anchor = Shortbread::Anchoring.capture(
      source: text, start_offset: text.index(quote), length: quote.length,
      release_number: 1, path: "index.html"
    )

    resolution = Shortbread::Anchoring.resolve(anchor, Shortbread::Extraction.from_html(restyled).text)

    assert_equal :exact, resolution.status
  end
end
