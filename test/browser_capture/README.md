# Browser capture spike — #66

Throwaway evidence harness for [#66](https://github.com/ZempTime/shortbread/issues/66). **Not part
of the test suite** and not run by CI. Outcome:
[`2026-07-25-t7-browser-capture-outcome.md`](../../docs/initiatives/2026-07-tater-tots-redirect/02_ticket_map/output/2026-07-25-t7-browser-capture-outcome.md).

These scripts depend on the prototype modules, which live in gitignored `tmp/`. Restore them first:

```sh
git checkout prototype/anchoring-2026-07-25 -- tmp/prototype-anchoring/
git restore --staged tmp/prototype-anchoring/   # the checkout stages them; they must not be committed
```

Then, with a local Chrome available:

```sh
bundle exec ruby test/browser_capture/browser_capture_spike.rb   # 13 driven selections + extractor diff
bundle exec ruby test/browser_capture/probe_edges.rb             # collapsed whitespace, block newlines, hidden text
bundle exec ruby test/browser_capture/probe_quotes.rb            # quote round-trip through capture/resolve
bundle exec ruby test/browser_capture/probe_hidden.rb            # whether hidden text corrupts capture
```

`extract_dom.js` is the JS twin of `Extract.from_html`, walking the live DOM. It mirrors the Ruby
scanner's rules **including its quirks** — notably skipping by tag name only, never by CSS — so that
any disagreement is a real finding rather than an artefact of two different extractors. See finding
1 in the outcome for why a CSS-aware client extractor breaks server-side verification.
