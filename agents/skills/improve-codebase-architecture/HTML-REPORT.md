# HTML Report Format

Render the architecture review as one fully offline, static HTML file in the OS temporary directory. Embed all CSS and diagrams. Do not load or link Tailwind, Mermaid, JavaScript, web fonts, images, stylesheets, or any other remote or local asset.

## Safety contract

- Add a restrictive CSP: `default-src 'none'; style-src 'unsafe-inline'; img-src data:; script-src 'none'; connect-src 'none'; font-src 'none'; object-src 'none'; media-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'`.
- Escape every repository-derived value before insertion: `&`, `<`, `>`, `"`, and `'`. This includes repository names, paths, symbols, snippets, ADR text, labels, and findings.
- Put escaped snippets inside `<pre><code>`. Never interpolate repository text as HTML, CSS, a URL, an element ID, or an event handler.
- Build diagrams from fixed HTML/SVG primitives and numeric geometry chosen by the report generator. Escape all SVG `<text>` labels. Do not use `<foreignObject>`, scripts, external references, data copied into style attributes, or active SVG features.
- Use fixed, generated identifiers that contain no repository-derived text.

## Scaffold

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta
      http-equiv="Content-Security-Policy"
      content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; script-src 'none'; connect-src 'none'; font-src 'none'; object-src 'none'; media-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'"
    />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Architecture review — {{escaped repo name}}</title>
    <style>
      :root { color-scheme: light; font-family: ui-sans-serif, system-ui, sans-serif; }
      body { margin: 0; background: #fafaf9; color: #0f172a; }
      main { max-width: 64rem; margin: auto; padding: 3rem 1.5rem; }
      header, section { margin-bottom: 3rem; }
      article { margin: 1.5rem 0; padding: 1.25rem; border: 1px solid #cbd5e1; border-radius: .75rem; background: #fff; }
      .badges, .wins { display: flex; flex-wrap: wrap; gap: .5rem; }
      .badge { padding: .2rem .55rem; border-radius: 999px; background: #e2e8f0; font-size: .75rem; }
      .diagrams { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; }
      .diagram { min-height: 18rem; padding: 1rem; border: 1px solid #e2e8f0; border-radius: .5rem; overflow: auto; }
      .module { padding: .65rem; border: 2px solid #475569; border-radius: .4rem; background: #f8fafc; }
      .deep { border-width: 5px; background: #e2e8f0; }
      .warning { padding: .75rem; border-left: 4px solid #d97706; background: #fffbeb; }
      .mono, code, pre { font-family: ui-monospace, monospace; }
      svg { width: 100%; height: auto; }
      .seam { stroke-dasharray: 4 4; }
      .leak { stroke: #dc2626; }
      @media (max-width: 48rem) { .diagrams { grid-template-columns: 1fr; } }
    </style>
  </head>
  <body>
    <main>
      <header>...</header>
      <section id="candidates">...</section>
      <section id="top-recommendation">...</section>
    </main>
  </body>
</html>
```

Only escaped data replaces placeholders.

## Header

Show the escaped repository name, date, and a compact legend: solid box = module, dashed line = seam, red arrow = leakage, thick box = deep module. Skip the introduction paragraph and lead with candidates.

## Candidate card

Each candidate is one `<article>`:

- **Title** — short and names the deepening.
- **Badges** — recommendation strength (`Strong`, `Worth exploring`, `Speculative`) and dependency category.
- **Files** — escaped monospaced text, never links assembled from repository paths.
- **Before / After** — the central pair of static diagrams.
- **Problem** and **Solution** — one sentence each.
- **Wins** — terse bullets expressed as leverage or locality.
- **ADR callout** — one warning when the candidate conflicts with an accepted decision.

If a diagram needs a paragraph, redraw it.

## Diagram patterns

Choose the smallest static pattern that communicates the relationship:

- **Call graph** — controlled inline SVG rectangles, lines, paths, and escaped `<text>` labels.
- **Boxes and arrows** — CSS module boxes with a fixed inline SVG overlay.
- **Cross-section** — stacked bands showing shallow pass-through modules versus one deep module.
- **Mass diagram** — paired interface/implementation rectangles showing relative depth.
- **Call-graph collapse** — before tree beside one deep after box with faded fixed internals.

No Mermaid source, layout engine, external icon, or remote renderer is permitted. Prefer fixed geometry over active content.

## Style and tone

- Lean editorial layout, generous whitespace, one accent, red only for leakage, amber only for warnings.
- Keep diagrams near 320px tall and usable at narrow viewports.
- Use the `codebase-design` vocabulary exactly: module, interface, implementation, depth, deep, shallow, seam, adapter, leverage, locality.
- Avoid hedging, dashboard decoration, and unexplained jargon.

End with one top recommendation: candidate name, one sentence on why, and a fixed local anchor to its card.
