# frozen_string_literal: true

# SPIKE PROBE — #66. How much damage does CSS-hidden text actually do?
#
# Both extractors emit display:none text; no browser will let a reviewer select it. The question
# is whether that is merely unreachable text (harmless) or whether it SHIFTS the offsets of text
# that IS selectable (fatal -- every anchor after the hidden block would be wrong).
#
# This matters most for the CLIENT/SERVER split: capture happens in the browser, verification
# happens in Ruby against the Blob. If the browser skips hidden text and Ruby does not, the two
# disagree and a captured anchor will not verify server-side.

require "selenium-webdriver"
require "tmpdir"

require_relative "../../tmp/prototype-anchoring/extract"
require_relative "../../tmp/prototype-anchoring/anchoring"
require_relative "../../tmp/prototype-anchoring/html_scenarios"

HARNESS_JS = File.read(File.expand_path("extract_dom.js", __dir__))

# A hidden block placed BEFORE content a reviewer will select, so any offset shift shows up.
HIDDEN_HTML = HtmlScenarios::H1.sub(
  "<h2>Failure modes</h2>",
  "<p style=\"display:none\">INVISIBLE SENTINEL TEXT</p>\n  <h2>Failure modes</h2>"
)

VISIBILITY_HTML = HtmlScenarios::H1.sub(
  "<h2>Failure modes</h2>",
  "<p style=\"visibility:hidden\">INVISIBLE SENTINEL TEXT</p>\n  <h2>Failure modes</h2>"
)

def with_browser
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  driver = Selenium::WebDriver.for(:chrome, options: options)
  yield driver
ensure
  driver&.quit
end

# Selects a phrase that sits AFTER the hidden block and reports where it landed.
AFTER_JS = <<~JS
  const [needle] = arguments;
  const ex = window.__anchorHarness.extractDom(document.body);
  const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  let node = null;
  while (w.nextNode()) if (w.currentNode.data.includes(needle)) { node = w.currentNode; break; }
  if (!node) return { error: "needle not in any text node" };

  const s = node.data.indexOf(needle);
  const sel = window.getSelection();
  sel.removeAllRanges();
  sel.setBaseAndExtent(node, s, node, s + needle.length);
  const mapped = window.__anchorHarness.rangeToOffsets(ex, sel.getRangeAt(0));

  return {
    mapped,
    selectionToString: sel.toString(),
    jsExtractionIncludesHidden: ex.text.includes("INVISIBLE SENTINEL TEXT"),
    jsQuote: ex.text.slice(mapped.start, mapped.end)
  };
JS

NEEDLE = "Retries are capped at three"

def probe(driver, label, html)
  path = File.join(Dir.tmpdir, "shortbread-t7-hidden-#{Process.pid}.html")
  File.write(path, html)
  driver.navigate.to("file://#{path}")
  driver.execute_script(HARNESS_JS)
  r = driver.execute_script(AFTER_JS, NEEDLE)
  File.delete(path)

  ruby_ex = Extract.from_html(html)

  puts "=" * 78
  puts label
  puts "=" * 78
  puts "  browser could select:      #{r["selectionToString"].inspect}"
  puts "  mapped to offsets:         [#{r["mapped"]["start"]}, #{r["mapped"]["end"]})"
  puts "  JS extraction has hidden:  #{r["jsExtractionIncludesHidden"]}"
  puts "  Ruby extraction has hidden:#{ruby_ex.text.include?("INVISIBLE SENTINEL TEXT")}"

  # The decisive check: does the offset the BROWSER produced select the SAME text in the RUBY
  # extraction, which is what the server stores and verifies against?
  ruby_quote = ruby_ex.text[r["mapped"]["start"]...r["mapped"]["end"]]
  puts "  RUBY text at that offset:  #{ruby_quote.inspect}"
  agree = ruby_quote == NEEDLE
  puts "  client/server agree:       #{agree ? "YES" : "NO — CAPTURE WOULD BE CORRUPT"}"

  anchor = Anchoring.capture(source: ruby_ex.text, start_offset: r["mapped"]["start"],
    length: r["mapped"]["end"] - r["mapped"]["start"], release_number: 1, path: "index.html")
  res = Anchoring.resolve(anchor, ruby_ex.text)
  puts "  resolves:                  #{res.status.upcase} conf=#{res.confidence}"
  puts "  stored quote:              #{anchor.quote.inspect}"
  puts
  agree
end

with_browser do |driver|
  a = probe(driver, "BASELINE — no hidden content", HtmlScenarios::H1)
  b = probe(driver, "display:none before the selection", HIDDEN_HTML)
  c = probe(driver, "visibility:hidden before the selection", VISIBILITY_HTML)

  puts "=" * 78
  puts "VERDICT"
  puts "=" * 78
  puts "baseline agree=#{a}  display:none agree=#{b}  visibility:hidden agree=#{c}"
  puts
  if b && c
    puts "Hidden text is UNREACHABLE BUT HARMLESS: both extractors include it identically, so"
    puts "offsets stay in lockstep and a captured anchor still verifies server-side."
  else
    puts "Hidden text CORRUPTS capture: the browser and Ruby disagree on offsets."
  end
end
