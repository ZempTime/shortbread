# frozen_string_literal: true

# SPIKE HARNESS — #66. Not product code, not part of the test suite.
#
# Drives real Selections in headless Chrome against the H1 fixture and asks two questions:
#
#   1. Does a live DOM Range map to the same extracted-text offset the Ruby extractor produces?
#   2. Do the Ruby and JS extractors agree on text and offset map for the same bytes?
#
# Run: bin/rails runner test/browser_capture/browser_capture_spike.rb
#  or: ruby test/browser_capture/browser_capture_spike.rb   (needs selenium-webdriver on the path)

require "selenium-webdriver"
require "json"
require "tmpdir"

require_relative "../../tmp/prototype-anchoring/extract"
require_relative "../../tmp/prototype-anchoring/anchoring"
require_relative "../../tmp/prototype-anchoring/html_scenarios"

HTML = HtmlScenarios::H1
HARNESS_JS = File.read(File.expand_path("extract_dom.js", __dir__))

RUBY_EX = Extract.from_html(HTML)

# Each case names a selection the way a reviewer would make it: by the visible text they drag
# across. The harness finds that text in the DOM itself, so the browser — not the fixture author —
# decides which nodes and offsets the Range lands on.
CASES = [
  { key: "a", label: "Prose, wholly inside one text node", needle: "roll back cleanly", nth: 0 },
  { key: "b", label: "Repeated sentence — FIRST", needle: "We must handle the case where the disk fills up.", nth: 0 },
  { key: "c", label: "Repeated sentence — SECOND", needle: "We must handle the case where the disk fills up.", nth: 1 },
  { key: "d", label: "Crosses an inline tag (<em>)", needle: "The operator sees a clear error", nth: 0 },
  { key: "e", label: "Is exactly the emphasised word", needle: "operator", nth: 0 },
  { key: "f", label: "A heading", needle: "Failure modes", nth: 0 },
  { key: "g", label: "Inside <pre> (whitespace preserved)", needle: "site.releases.create!(number: next_number)", nth: 0 },
  { key: "h", label: "A table cell", needle: "Monotonic Release counter", nth: 0 },
  { key: "i", label: "Spans a block boundary (p into h2)", needle: "halfway through.\nFailure modes", nth: 0 },
  { key: "j", label: "BACKWARDS drag (right-to-left)", needle: "exponential backoff", nth: 0, backwards: true },
  { key: "k", label: "Endpoints land on collapsed whitespace", needle: "filesystem. This lets us", nth: 0 },
  { key: "l", label: "Starts at an entity (&mdash;)", needle: nil, nth: 0, entity: true },
  { key: "m", label: "CSS-hidden text (display:none)", needle: nil, nth: 0, hidden: true }
].freeze

def with_browser
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  driver = Selenium::WebDriver.for(:chrome, options: options)
  yield driver
ensure
  driver&.quit
end

# The fixture is served as a real document so the browser applies its own whitespace and
# visibility rules, which is the entire point of the exercise.
def fixture_path(html)
  path = File.join(Dir.tmpdir, "shortbread-t7-fixture-#{Process.pid}.html")
  File.write(path, html)
  path
end

# Builds a Range across the requested visible text using the browser's own text, then reads back
# the extracted-text offsets the harness derives from it.
DRIVE_JS = <<~JS
  const [needle, nth, backwards] = arguments;
  const ex = window.__anchorHarness.extractDom(document.body);

  // Find the needle in the BROWSER's extracted text, then translate that text index back to a
  // DOM position, so the Range is built from the browser's own view of the document.
  let from = -1;
  for (let n = 0; n <= nth; n++) from = ex.text.indexOf(needle, from + 1);
  if (from < 0) return { error: "needle not found in extracted text" };
  const to = from + needle.length;

  // Text index -> DOM position. Skip synthesised newlines by walking inward to a real character.
  const domPos = (i, dir) => {
    let j = i;
    while (j >= 0 && j < ex.nodeMap.length && ex.nodeMap[j] === null) j += dir;
    const m = ex.nodeMap[j];
    if (!m) return null;
    return { node: ex.nodes[m[0]], offset: dir > 0 ? m[1] : m[1] + 1 };
  };

  const s = domPos(from, 1);
  const e = domPos(to - 1, -1);
  if (!s || !e) return { error: "could not map text index to DOM position" };

  const sel = window.getSelection();
  sel.removeAllRanges();

  if (backwards) {
    // A right-to-left drag: anchor at the END, focus at the START. This is what the browser
    // reports when a user drags backwards, and it is what the prototype never considered.
    sel.setBaseAndExtent(e.node, e.offset, s.node, s.offset);
  } else {
    sel.setBaseAndExtent(s.node, s.offset, e.node, e.offset);
  }

  if (sel.rangeCount === 0) return { error: "no range produced" };
  const range = sel.getRangeAt(0);
  const mapped = window.__anchorHarness.rangeToOffsets(ex, range);

  return {
    expectedStart: from,
    expectedEnd: to,
    mapped,
    selectionToString: sel.toString(),
    rangeToString: range.toString(),
    isBackwards: sel.anchorNode === e.node && sel.anchorOffset === e.offset && backwards,
    quoteFromExtracted: mapped ? ex.text.slice(mapped.start, mapped.end) : null
  };
JS

EXTRACT_JS = <<~JS
  const ex = window.__anchorHarness.extractDom(document.body);
  return { text: ex.text, nullCount: ex.nodeMap.filter(m => m === null).length };
JS

def run
  results = []
  path = fixture_path(HTML)

  with_browser do |driver|
    driver.navigate.to("file://#{path}")
    driver.execute_script(HARNESS_JS)

    js_ex = driver.execute_script(EXTRACT_JS)

    puts "=" * 78
    puts "PART 1 — Extractor agreement (Ruby vs JS-on-live-DOM)"
    puts "=" * 78
    ruby_text = RUBY_EX.text
    js_text = js_ex["text"]
    puts "Ruby text length: #{ruby_text.length}"
    puts "JS   text length: #{js_text.length}"
    if ruby_text == js_text
      puts "IDENTICAL ✓"
    else
      puts "DIFFERENT ✗"
      report_diff(ruby_text, js_text)
    end
    puts "Synthesised block newlines (no selectable character): #{js_ex["nullCount"]}"
    puts

    puts "=" * 78
    puts "PART 2 — Live Selection -> extracted-text offset"
    puts "=" * 78

    CASES.each do |c|
      result = drive_case(driver, c, path)
      results << result
      print_case(c, result)
    end
  end

  puts
  puts "=" * 78
  puts "SUMMARY"
  puts "=" * 78
  pass = results.count { |r| r[:verdict] == :pass }
  puts "#{pass}/#{results.length} selections mapped to the expected extracted-text offset"
  results.reject { |r| r[:verdict] == :pass }.each do |r|
    puts "  #{r[:key]} #{r[:verdict].to_s.upcase}: #{r[:note]}"
  end
ensure
  File.delete(path) if path && File.exist?(path)
end

def drive_case(driver, c, path)
  # The entity and hidden-text cases need a different document, so they re-navigate.
  if c[:entity]
    html = HTML.sub("The installer writes a manifest",
      "The installer &mdash; and only the installer &mdash; writes a manifest")
    return drive_variant(driver, c, html, "and only the installer")
  end

  if c[:hidden]
    html = HTML.sub("<h2>Failure modes</h2>",
      "<p style=\"display:none\">INVISIBLE SENTINEL TEXT</p>\n  <h2>Failure modes</h2>")
    return drive_hidden(driver, c, html)
  end

  driver.navigate.to("file://#{path}")
  driver.execute_script(HARNESS_JS)
  evaluate(driver, c, c[:needle], RUBY_EX)
end

def drive_variant(driver, c, html, needle)
  vpath = fixture_path(html)
  driver.navigate.to("file://#{vpath}")
  driver.execute_script(HARNESS_JS)
  ruby_ex = Extract.from_html(html)
  out = evaluate(driver, c, needle, ruby_ex)
  File.delete(vpath) if File.exist?(vpath)
  out
end

# The hidden-text case asks a different question: does the extractor emit text the browser will
# not let a reviewer select? Verdict is about presence, not offsets.
def drive_hidden(driver, c, html)
  vpath = fixture_path(html)
  driver.navigate.to("file://#{vpath}")
  driver.execute_script(HARNESS_JS)
  js = driver.execute_script(EXTRACT_JS)
  ruby_ex = Extract.from_html(html)

  in_ruby = ruby_ex.text.include?("INVISIBLE SENTINEL TEXT")
  in_js = js["text"].include?("INVISIBLE SENTINEL TEXT")
  File.delete(vpath) if File.exist?(vpath)

  {
    key: c[:key], label: c[:label],
    verdict: (in_ruby || in_js) ? :fail : :pass,
    note: "hidden text present in Ruby=#{in_ruby} JS=#{in_js} (a reviewer can select neither)"
  }
end

def evaluate(driver, c, needle, ruby_ex)
  raw = driver.execute_script("#{DRIVE_JS}", needle, c[:nth] || 0, !!c[:backwards])

  if raw["error"]
    return { key: c[:key], label: c[:label], verdict: :error, note: raw["error"] }
  end

  mapped = raw["mapped"]
  expected_start = raw["expectedStart"]
  expected_end = raw["expectedEnd"]

  # The browser's own extracted text is the JS side. Cross-check the SAME offset against the
  # RUBY extraction, which is what the server will store and verify against.
  ruby_slice = ruby_ex.text[expected_start...expected_end]
  ruby_agrees = ruby_slice == needle

  ok = mapped &&
    mapped["start"] == expected_start &&
    mapped["end"] == expected_end &&
    ruby_agrees

  note = if mapped.nil?
    "range did not map"
  elsif mapped["start"] != expected_start || mapped["end"] != expected_end
    "mapped [#{mapped["start"]},#{mapped["end"]}) expected [#{expected_start},#{expected_end}) " \
      "got #{raw["quoteFromExtracted"].inspect}"
  elsif !ruby_agrees
    "browser offset does not select the same text in the RUBY extraction: #{ruby_slice.inspect}"
  else
    "selection.toString=#{raw["selectionToString"].inspect}"
  end

  {
    key: c[:key], label: c[:label], verdict: ok ? :pass : :fail, note: note,
    selection_string: raw["selectionToString"], expected: [expected_start, expected_end],
    mapped: mapped && [mapped["start"], mapped["end"]]
  }
end

def print_case(c, r)
  mark = { pass: "✓", fail: "✗", error: "!" }.fetch(r[:verdict])
  puts "#{mark} (#{r[:key]}) #{r[:label]}"
  puts "    #{r[:note]}"
end

def report_diff(a, b)
  n = [a.length, b.length].min
  i = 0
  i += 1 while i < n && a[i] == b[i]
  puts "  First divergence at character #{i}:"
  puts "    Ruby: #{a[[i - 30, 0].max, 80].inspect}"
  puts "    JS  : #{b[[i - 30, 0].max, 80].inspect}"
end

run
