# frozen_string_literal: true

require "application_system_test_case"

require "json"
require "open3"

# Criterion 6's real check: the TypeScript extractor walking a live DOM in a real browser must
# produce the same text — and therefore the same offsets — as the Ruby extractor produces from the
# same bytes. A divergence here is what silently breaks server-side Anchor verification, and it is
# invisible to a unit test because only a browser builds a real DOM.
#
# The browser-capture spike (#66) found exactly one such divergence: a DOM walker that breaks only
# on ENTERING a block lets the whitespace after `</h1>` survive as a space. The extraction
# fixtures below include that case.
class AnchoringConformanceSystemTest < ApplicationSystemTestCase
  FIXTURES = JSON.parse(
    Rails.root.join("test/frontend/conformance_fixtures.json").read,
    symbolize_names: true
  ).freeze

  EXTRACTION_MODULE = Rails.root.join("app/frontend/anchoring/extraction.ts").freeze

  test "the DOM extractor agrees with the Ruby extractor on every shared fixture" do
    divergences = FIXTURES.fetch(:extraction).filter_map do |fixture|
      html = fixture.fetch(:html)
      from_browser = extract_in_browser(html)
      from_ruby = Shortbread::Extraction.from_html(html).text

      next if from_browser == from_ruby && from_ruby == fixture.fetch(:text)

      {
        name: fixture.fetch(:name), expected: fixture.fetch(:text),
        ruby: from_ruby, browser: from_browser
      }
    end

    assert_empty divergences, divergence_report(divergences)
  end

  test "a live Selection captures the Anchor the Ruby extractor can verify" do
    html = "<h1>Deploy notes</h1><p>Every change <em>ships</em> behind a flag.</p>"
    quote = "ships behind a flag"
    expected_text = Shortbread::Extraction.from_html(html).text

    captured = capture_selection_in_browser(html:, quote:)

    assert_equal quote, captured.fetch("quote"),
      "the browser captured a different quote than the reviewer selected"
    assert_equal expected_text.index(quote), captured.fetch("startOffset"),
      "the browser's offset does not agree with the Ruby extraction"

    anchor = Shortbread::Anchoring.capture(
      source: expected_text, start_offset: captured.fetch("startOffset"),
      length: captured.fetch("quote").length, release_number: 1, path: "index.html"
    )
    resolution = Shortbread::Anchoring.resolve(anchor, expected_text)

    assert_equal :exact, resolution.status
    assert_in_delta 1.0, resolution.confidence, 0.001
  end

  test "a backwards drag captures the same Anchor as a forwards one" do
    html = "<p>Every change ships behind a flag.</p>"
    quote = "ships behind a flag"

    forwards = capture_selection_in_browser(html:, quote:)
    backwards = capture_selection_in_browser(html:, quote:, backwards: true)

    assert_equal forwards.fetch("quote"), backwards.fetch("quote")
    assert_equal forwards.fetch("startOffset"), backwards.fetch("startOffset")
  end

  private

  def extract_in_browser(html)
    evaluate_with_module(html, <<~JS)
      const root = document.getElementById('fixture');
      return fromDom(root).text;
    JS
  end

  def capture_selection_in_browser(html:, quote:, backwards: false)
    evaluate_with_module(html, <<~JS)
      const root = document.getElementById('fixture');
      const extracted = fromDom(root);
      const target = #{quote.to_json};

      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      let startNode = null, startOffset = 0, endNode = null, endOffset = 0;
      let seen = '';
      const nodes = [];
      while (walker.nextNode()) nodes.push(walker.currentNode);

      // Locate the reviewer's selection by its visible text, so the browser decides which nodes
      // and offsets the Range lands on rather than the fixture author.
      for (const node of nodes) {
        for (let i = 0; i < node.data.length; i += 1) {
          const character = node.data[i];
          if (character === target[seen.length]) {
            if (seen.length === 0) { startNode = node; startOffset = i; }
            seen += character;
            if (seen.length === target.length) { endNode = node; endOffset = i + 1; break; }
          } else {
            seen = ''; startNode = null;
            if (character === target[0]) { startNode = node; startOffset = i; seen = character; }
          }
        }
        if (seen.length === target.length) break;
      }
      if (!startNode || !endNode) return { error: 'selection text not found' };

      const selection = window.getSelection();
      selection.removeAllRanges();
      if (#{backwards ? "true" : "false"}) {
        selection.setBaseAndExtent(endNode, endOffset, startNode, startOffset);
      } else {
        selection.setBaseAndExtent(startNode, startOffset, endNode, endOffset);
      }

      const anchor = captureFromSelection({
        root, selection, releaseNumber: 1, path: 'index.html'
      });
      return anchor ? { quote: anchor.quote, startOffset: anchor.startOffset } : { error: 'no anchor' };
    JS
  end

  # Serves the fixture and the compiled modules from a data URL, so the browser runs the real
  # TypeScript source rather than a hand-copied approximation of it.
  def evaluate_with_module(html, body)
    visit "data:text/html;charset=utf-8,#{ERB::Util.url_encode("<!doctype html><body><div id='fixture'>#{html}</div></body>")}"

    result = page.evaluate_script(<<~JS)
      (() => {
        #{compiled_modules}
        #{body}
      })()
    JS

    raise result.fetch("error") if result.is_a?(Hash) && result["error"]

    result
  end

  SOURCES = %w[
    app/frontend/anchoring/anchoring.ts
    app/frontend/anchoring/extraction.ts
    app/frontend/anchoring/capture.ts
  ].freeze

  # `module.stripTypeScriptTypes` erases annotations without transforming semantics, so the
  # browser runs the real source rather than a hand-copied approximation, and no bundler
  # dependency is added to the baseline.
  def compiled_modules
    @compiled_modules ||= begin
      script = <<~JS
        const { stripTypeScriptTypes } = require('node:module');
        const { readFileSync } = require('node:fs');
        const sources = #{SOURCES.to_json};
        // Concatenating modules into one scope drops the import lines, so any `as` alias they
        // introduced has to be re-declared or the aliased name is simply undefined at runtime.
        const aliases = [];
        const stripped = sources.map((path) => {
          const source = stripTypeScriptTypes(readFileSync(path, 'utf8'), { mode: 'strip' });
          for (const line of source.match(/^import[^\\n]*\\n/gm) ?? []) {
            for (const [, original, alias] of line.matchAll(/(\\w+)\\s+as\\s+(\\w+)/g)) {
              if (original !== 'type') aliases.push(`const ${alias} = ${original};`);
            }
          }
          return source.replace(/^import[^\\n]*\\n/gm, '').replace(/^export /gm, '');
        });
        // Aliases go last: they reference functions the modules declare, and every call site is
        // inside a function body that does not run until after the whole bundle is evaluated.
        process.stdout.write(stripped.join('\\n') + '\\n' + aliases.join('\\n'));
      JS
      output, status = Open3.capture2("node", "--eval", script, chdir: Rails.root.to_s)
      raise "type stripping failed" unless status.success?

      output
    end
  end

  def divergence_report(divergences)
    divergences.map do |divergence|
      <<~REPORT
        #{divergence.fetch(:name)}
          expected: #{divergence.fetch(:expected).inspect}
          ruby:     #{divergence.fetch(:ruby).inspect}
          browser:  #{divergence.fetch(:browser).inspect}
      REPORT
    end.join("\n")
  end
end
