# frozen_string_literal: true

# SPIKE PROBE — #66. Interrogates the cases most likely to be passing for the wrong reason.
#
# The main harness builds its Range by translating an extracted-text index back to a DOM position.
# That is the capture direction we care about, but it means the harness picks "nice" endpoints.
# This probe instead places endpoints DELIBERATELY on the awkward positions -- inside a collapsed
# whitespace run, on a synthesised block newline, and inside display:none content -- and reports
# what the mapping does, rather than asserting it is right.

require "selenium-webdriver"
require "json"
require "tmpdir"

require_relative "../../tmp/prototype-anchoring/extract"
require_relative "../../tmp/prototype-anchoring/html_scenarios"

HARNESS_JS = File.read(File.expand_path("extract_dom.js", __dir__))

def with_browser
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  driver = Selenium::WebDriver.for(:chrome, options: options)
  yield driver
ensure
  driver&.quit
end

def load(driver, html)
  path = File.join(Dir.tmpdir, "shortbread-t7-probe-#{Process.pid}.html")
  File.write(path, html)
  driver.navigate.to("file://#{path}")
  driver.execute_script(HARNESS_JS)
  File.delete(path)
end

# --- Probe 1: endpoints placed INSIDE a collapsed whitespace run -------------------------------
COLLAPSED_JS = <<~JS
  const ex = window.__anchorHarness.extractDom(document.body);
  // The fixture wraps this paragraph mid-sentence, so "us\\n      roll" is a real collapsed run.
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  let target = null;
  while (walker.nextNode()) {
    if (walker.currentNode.data.includes("This lets us")) { target = walker.currentNode; break; }
  }
  if (!target) return { error: "target node not found" };

  const d = target.data;
  const runStart = d.indexOf("This lets us") + "This lets us".length;
  let runEnd = runStart;
  while (runEnd < d.length && /\\s/.test(d[runEnd])) runEnd++;

  const out = [];
  for (let off = runStart; off <= runEnd; off++) {
    out.push({
      domOffset: off,
      charAtOffset: JSON.stringify(d[off] === undefined ? null : d[off]),
      asStart: window.__anchorHarness.positionToOffset(ex, ex.nodes.indexOf(target), off, "start"),
      asEnd: window.__anchorHarness.positionToOffset(ex, ex.nodes.indexOf(target), off, "end")
    });
  }
  return { runLength: runEnd - runStart, probes: out, text: ex.text };
JS

# --- Probe 2: does a user-made selection ever START on a synthesised newline? -------------------
BLOCK_NEWLINE_JS = <<~JS
  const ex = window.__anchorHarness.extractDom(document.body);
  const nulls = [];
  ex.nodeMap.forEach((m, i) => { if (m === null) nulls.push(i); });
  // Select across a block boundary the way a user drags: from inside the <p> to inside the <h2>.
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  let pNode = null, hNode = null;
  while (walker.nextNode()) {
    const n = walker.currentNode;
    if (!pNode && n.data.includes("halfway through")) pNode = n;
    else if (pNode && !hNode && n.data.includes("Failure modes")) hNode = n;
  }
  if (!pNode || !hNode) return { error: "nodes not found" };

  const sel = window.getSelection();
  sel.removeAllRanges();
  sel.setBaseAndExtent(pNode, pNode.data.indexOf("halfway"), hNode, hNode.data.indexOf("Failure modes") + 13);
  const mapped = window.__anchorHarness.rangeToOffsets(ex, sel.getRangeAt(0));
  return {
    synthesisedNewlineIndices: nulls,
    mapped,
    extractedSlice: ex.text.slice(mapped.start, mapped.end),
    selectionToString: sel.toString(),
    sliceContainsNewline: ex.text.slice(mapped.start, mapped.end).includes("\\n")
  };
JS

# --- Probe 3: is display:none text selectable by a real drag? -----------------------------------
HIDDEN_JS = <<~JS
  const ex = window.__anchorHarness.extractDom(document.body);
  const sentinel = "INVISIBLE SENTINEL TEXT";
  const idx = ex.text.indexOf(sentinel);

  // Ask the browser to select the WHOLE body, as a select-all would, and see what it reports.
  const sel = window.getSelection();
  sel.removeAllRanges();
  const r = document.createRange();
  r.selectNodeContents(document.body);
  sel.addRange(r);

  return {
    presentInExtraction: idx,
    presentInSelectionToString: sel.toString().includes(sentinel),
    presentInInnerText: document.body.innerText.includes(sentinel),
    presentInTextContent: document.body.textContent.includes(sentinel)
  };
JS

with_browser do |driver|
  puts "=" * 78
  puts "PROBE 1 — endpoints placed inside a collapsed whitespace run"
  puts "=" * 78
  load(driver, HtmlScenarios::H1)
  r = driver.execute_script(COLLAPSED_JS)
  if r["error"]
    puts r["error"]
  else
    puts "Collapsed run length in the DOM: #{r["runLength"]} characters"
    puts "(the extractor emits ONE space for this entire run)"
    puts
    puts "  domOffset  char      asStart -> asEnd"
    r["probes"].each do |p|
      puts format("  %9d  %-8s  %5d -> %5d", p["domOffset"], p["charAtOffset"], p["asStart"], p["asEnd"])
    end
    starts = r["probes"].map { |p| p["asStart"] }.uniq
    ends = r["probes"].map { |p| p["asEnd"] }.uniq
    puts
    puts "Distinct start offsets: #{starts.inspect}"
    puts "Distinct end   offsets: #{ends.inspect}"
    puts(starts.length == 1 && ends.length == 1 ?
      "STABLE — every position in the run maps to the same offset." :
      "UNSTABLE — position within the run changes the offset.")
  end

  puts
  puts "=" * 78
  puts "PROBE 2 — synthesised block newlines inside a real cross-block selection"
  puts "=" * 78
  load(driver, HtmlScenarios::H1)
  r = driver.execute_script(BLOCK_NEWLINE_JS)
  if r["error"]
    puts r["error"]
  else
    puts "Synthesised newline indices: #{r["synthesisedNewlineIndices"].inspect}"
    puts "Mapped: #{r["mapped"].inspect}"
    puts "Extracted slice: #{r["extractedSlice"].inspect}"
    puts "selection.toString: #{r["selectionToString"].inspect}"
    puts "Slice contains a synthesised newline: #{r["sliceContainsNewline"]}"
  end

  puts
  puts "=" * 78
  puts "PROBE 3 — display:none text"
  puts "=" * 78
  hidden_html = HtmlScenarios::H1.sub("<h2>Failure modes</h2>",
    "<p style=\"display:none\">INVISIBLE SENTINEL TEXT</p>\n  <h2>Failure modes</h2>")
  load(driver, hidden_html)
  r = driver.execute_script(HIDDEN_JS)
  ruby_ex = Extract.from_html(hidden_html)
  puts "Index in JS extraction:            #{r["presentInExtraction"]}"
  puts "Index in RUBY extraction:          #{ruby_ex.text.index("INVISIBLE SENTINEL TEXT").inspect}"
  puts "In selection.toString (select all): #{r["presentInSelectionToString"]}"
  puts "In body.innerText:                 #{r["presentInInnerText"]}"
  puts "In body.textContent:               #{r["presentInTextContent"]}"
end
