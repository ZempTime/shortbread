# plannotator: verified source analysis

Source: `github.com/backnotprop/plannotator`, cloned at HEAD `193b07e`, version `0.24.2`,
read 2026-07-25. License: `MIT OR Apache-2.0` at the repo root. Everything below was read from
source, not inferred from the README.

## What it is

A local, ephemeral review surface between you and your AI coding agent. A compiled Bun binary
starts an HTTP server on a random port and opens your browser. You annotate, and structured
feedback goes straight back into the agent session.

```
Agent calls ExitPlanMode -> PermissionRequest hook fires -> local server reads plan
  -> browser opens review UI -> you annotate and approve/deny
    -> Approve: agent proceeds
    -> Deny: structured feedback sent to agent -> agent revises -> plan diff shows what changed
```

Artifact types: markdown plans, code diffs (git or PR/MR URL), rendered HTML, a directory of
files, a URL, or the agent's last message.

## The anchoring model (the important part)

From `packages/ui/types.ts`, verbatim:

```ts
/** DOM-relative text position used to restore a document annotation selection. */
export interface AnnotationTextMeta {
  parentTagName: string;
  parentIndex: number;
  textOffset: number;
}

export interface Annotation {
  id: string;
  blockId: string;      // Legacy - not used with web-highlighter
  startOffset: number;  // Legacy
  endOffset: number;    // Legacy
  type: AnnotationType; // DELETION | COMMENT | GLOBAL_COMMENT
  text?: string;        // For comments
  originalText: string; // The text that was selected
  createdA: number;     // sic - real typo in shipped source
  author?: string;      // "Tater identity for collaborative sharing"
  source?: string;
  images?: ImageAttachment[];
  isQuickLabel?: boolean;
  diffContext?: 'added' | 'removed' | 'modified';
  startMeta?: AnnotationTextMeta;  // web-highlighter metadata
  endMeta?: AnnotationTextMeta;
}
```

**The anchor is a DOM position plus an exact text quote.** `parentTagName` + `parentIndex`
(index among same-tag siblings) + `textOffset`, captured for start and end. This is the
`web-highlighter` serialization format — not XPath, not a CSS selector, not W3C Web Annotation.

**There is no prefix/suffix context.** `originalText` is the only content-based anchor. Nothing
disambiguates a repeated string.

## Re-anchoring: crude, and it matters

`packages/ui/hooks/useAnnotationHighlighter.ts` (1,208 lines) restores in two tiers:

1. `highlighter.fromStore(startMeta, endMeta, originalText, id)`. If `verifyRestoredContent` is
   on, compare the painted text against `originalText`, whitespace-normalized.
2. On mismatch, fall back to `findTextInDOM(originalText)` — a plain **exact substring walk**
   over text nodes.
3. On failure: `console.warn`, optional `onRestoreMismatch` callback, annotation is **not
   painted**.

No fuzzy matching, no diff-match-patch, no similarity scoring. **No orphan state in the data
model** — an annotation whose text changed at all is silently dropped from view. And
`verifyRestoredContent` **defaults to false** ("positions are trusted"), so by default a stale
position paints onto whatever text now occupies it.

**Design caution for us:** this model mis-anchors on any document that changes between
annotation and display, and silently anchors to the first occurrence of a repeated string.
plannotator has the *shape* of resilient anchoring without the substance. If we want
W3C-style resilient anchoring (text quote + prefix/suffix context), **we design it ourselves.**

Our immutable content-addressed Releases make this materially easier: an annotation against
Release N always has an exact, unchanging document. The hard case is only carrying annotations
*forward* across a republish — which is a deliberate feature decision, not an accident.

## Feedback serialization: Markdown, not JSON

`exportAnnotations()` at `packages/ui/utils/parser.ts:775`:

```
# Plan Feedback

I've reviewed this plan and have 2 pieces of feedback:

## 1. (line 12) Feedback on: "the selected text"
> my comment

## 2. Remove this
```
the deleted text
```
> I don't want this in the plan.
```

Wrapped by `planDenyFeedback()` in `packages/core/feedback-templates.ts`:
`"YOUR PLAN WAS NOT APPROVED.\n\nYou MUST revise the plan to address ALL of the feedback
below..."`.

Note: **the durable anchor is discarded at export.** The agent receives a line number and a
quote, nothing more.

## Reusability verdict: do not harvest the editor

`packages/editor/App.tsx` is **215 KB / ~4,824 lines in one file**, and its signature is:

```ts
const App: React.FC = () => {
```

**Zero props.** It takes no document and no annotations, and emits no events. It self-fetches
from 13 hardcoded same-origin endpoints (`/api/plan`, `/api/feedback`, `/api/approve`,
`/api/deny`, `/api/exit`, `/api/upload`, `/api/share-html`, ...) plus an SSE stream, and reads
`window.location.origin`. It is an application, not a component. Rewriting it as
props-in/events-out *is* rewriting it.

Package boundaries confirm this: `@plannotator/editor` and `@plannotator/review-editor` are
both `version: 0.0.1` with `exports: { ".": "./App.tsx" }` — raw TSX source, no build, no
`main`/`types`. They depend on `workspace:*` siblings, several marked `"private": true`.
Consuming them means consuming the monorepo.

### What IS worth harvesting

1. **`packages/ui/utils/parser.ts`** (~1,097 lines) — markdown → `Block[]` with per-block source
   line tracking. Handles YAML frontmatter, GFM alerts, `:::` directives, tables, math. Only
   non-type import is `planDenyFeedback`. **The single best harvest target.**
2. **`exportAnnotations()`** (`parser.ts:775–880`) — ~150 self-contained lines, near-zero deps.
3. **`packages/core/feedback-templates.ts`** — deliberately node-free, directly liftable.
4. **`packages/ui/types.ts`** — copy the *shape* (id, type, originalText, comment, author),
   **not** the anchor design.

### Constraints if we pull from `packages/ui`

- **React 19.2.3 and Tailwind v4 are hard peer-dep requirements.** On React 18 this path closes.
- `packages/ui` is 48.7k LOC across 141 components and pulls CodeMirror 6 (12 packages),
  mermaid, katex, viz.js, highlight.js, motion, @base-ui/react, @tanstack/react-table.
- The highlighter depends on `@plannotator/web-highlighter ^0.8.1`, an unpublished-looking
  scoped package **whose license was not verified**. It is load-bearing for anchoring.
- None of `editor`, `review-editor`, or `ui` declares a `license` field in its own
  package.json — they inherit by repo convention. If we vendor files, copy `LICENSE-MIT`
  alongside them.

### Effort estimate (from the analysis, unvalidated by us)

- Annotation model + markdown export: ~1 day.
- A working selection → highlight → comment surface: **1–2 weeks**, because it means either
  adopting `web-highlighter` or reimplementing `fromStore`, plus stripping `packages/ui`
  internals the hook reaches into.

## Coverage gap

`packages/review-editor`'s `App.tsx` internals were not read — only its manifest and file
listing (31k LOC). It has the identical propless `exports: "./App.tsx"` shape, so the same
verdict is expected but **unverified**.
