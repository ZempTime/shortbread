# frozen_string_literal: true

# SPIKE PROBE — #66. The question that actually matters for anchoring.
#
# Probe 1 showed a DOM position inside a collapsed whitespace run can map to two adjacent offsets.
# That is only a PROBLEM if it changes the captured quote in a way that changes resolution. This
# probe drags the awkward selections and reports the resulting Anchor and its resolution against
# the same document -- the round trip #65 would actually perform.

require "selenium-webdriver"
require "tmpdir"

require_relative "../../tmp/prototype-anchoring/extract"
require_relative "../../tmp/prototype-anchoring/anchoring"
require_relative "../../tmp/prototype-anchoring/html_scenarios"

HARNESS_JS = File.read(File.expand_path("extract_dom.js", __dir__))
HTML = HtmlScenarios::H1
RUBY_EX = Extract.from_html(HTML)

def with_browser
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  driver = Selenium::WebDriver.for(:chrome, options: options)
  yield driver
ensure
  driver&.quit
end

# Drags from a DOM position to a DOM position, chosen by (node substring, offset within it), so
# the endpoints are placed deliberately rather than derived from the extraction.
DRAG_JS = <<~JS
  const [startNeedle, startOff, endNeedle, endOff] = arguments;
  const ex = window.__anchorHarness.extractDom(document.body);
  const find = (needle) => {
    const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    while (w.nextNode()) if (w.currentNode.data.includes(needle)) return w.currentNode;
    return null;
  };
  const sNode = find(startNeedle), eNode = find(endNeedle);
  if (!sNode || !eNode) return { error: "node not found" };

  const s = sNode.data.indexOf(startNeedle) + startOff;
  const e = eNode.data.indexOf(endNeedle) + endOff;

  const sel = window.getSelection();
  sel.removeAllRanges();
  sel.setBaseAndExtent(sNode, s, eNode, e);
  const mapped = window.__anchorHarness.rangeToOffsets(ex, sel.getRangeAt(0));
  return { mapped, selectionToString: sel.toString(), extracted: ex.text };
JS

CASES = [
  { name: "start ON the newline of a collapsed run",
    args: ["This lets us", "This lets us".length, "roll back cleanly", "roll back cleanly".length] },
  { name: "start MID collapsed run (2nd whitespace char)",
    args: ["This lets us", "This lets us".length + 1, "roll back cleanly", "roll back cleanly".length] },
  { name: "start AFTER the run, on content",
    args: ["This lets us", "This lets us".length + 3, "roll back cleanly", "roll back cleanly".length] },
  { name: "end MID collapsed run",
    args: ["The installer writes", 0, "This lets us", "This lets us".length + 2] },
  { name: "inside <pre>, spanning its preserved newline",
    args: ["def provision(site)", 0, "site.releases.create!", "site.releases.create!".length] }
]

with_browser do |driver|
  path = File.join(Dir.tmpdir, "shortbread-t7-quotes-#{Process.pid}.html")
  File.write(path, HTML)
  driver.navigate.to("file://#{path}")
  driver.execute_script(HARNESS_JS)

  CASES.each do |c|
    r = driver.execute_script(DRAG_JS, *c[:args])
    puts "=" * 78
    puts c[:name]
    puts "=" * 78
    if r["error"]
      puts "  #{r["error"]}"
      next
    end
    m = r["mapped"]
    quote = RUBY_EX.text[m["start"]...m["end"]]
    puts "  mapped offsets:     [#{m["start"]}, #{m["end"]})"
    puts "  selection.toString: #{r["selectionToString"].inspect}"
    puts "  RUBY quote at those offsets: #{quote.inspect}"

    anchor = Anchoring.capture(source: RUBY_EX.text, start_offset: m["start"],
      length: m["end"] - m["start"], release_number: 1, path: "index.html")
    res = Anchoring.resolve(anchor, RUBY_EX.text)
    puts "  resolve against same document: #{res.status.upcase} conf=#{res.confidence} — #{res.note}"
    puts "  quote round-trips: #{(quote == anchor.quote) && res.start_offset == m["start"]}"
    puts
  end

  File.delete(path)
end
