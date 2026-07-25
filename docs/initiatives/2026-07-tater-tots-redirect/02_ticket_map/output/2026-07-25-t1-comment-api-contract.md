# API contract — range-anchored Comments (T1 / #65)

Delivered by [#65](https://github.com/ZempTime/shortbread/issues/65). Parent PRD
[#64](https://github.com/ZempTime/shortbread/issues/64).

Three surfaces: two on the Site origin for the Viewer, one on the apex for the Producer.

## Offsets are Unicode code points

Both anchoring implementations count **code points**, not UTF-16 code units. Ruby counts this way
natively and the server is what verifies an Anchor against stored bytes, so the server's unit is
canonical; the TypeScript twin converts at the DOM boundary. One astral character (an emoji) is 1
code point but 2 UTF-16 units, so counting the JavaScript way desyncs every offset after it.

## Review surface injection — Site origin

An HTML response from a Site host carries the review surface as one script tag appended before
`</body>`, stamped with the Release it was served from:

```html
<script type="module" data-shortbread-release="2" src="/_shortbread/review.js"></script>
```

The stored Blob is never rewritten — the Release stays content-addressed to the uploaded bytes and
the ETag remains the Blob digest. Injection is a property of the response, not of the content.

## `POST /_shortbread/comments` — Site origin

Requires a valid Grant-backed Site session cookie. Leaves a Comment on the Site's current Release.

```json
{ "body": "Which flag is this?",
  "path": "index.html",
  "quote": "ships behind a flag",
  "start_offset": 26 }
```

`path`, `quote`, and `start_offset` are the Anchor and are optional **as a group** — omitting all
three leaves a Site-level Comment with no selection ([#69](https://github.com/ZempTime/shortbread/issues/69)).

The submitted Anchor is never trusted. The server re-extracts the document from the Release's
stored Blob and confirms the claimed quote sits at the claimed offset; `prefix`, `suffix`, and the
structural position are re-derived from the server's own extraction rather than taken from the
payload.

| Response | When |
|---|---|
| `201` with `{"id": …}` | Stored |
| `422` | Quote does not match the stored bytes at that offset; offset out of range; path absent from the Manifest; empty body |
| `404` | No Site session, revoked Grant, wrong host, or no current Release |

## `GET /_shortbread/comments?path=<manifest path>` — Site origin

Requires the same session. Returns the Comments on the current Release for one path, each with its
Anchor resolved against that Release's bytes so the surface can repaint it.

```json
{ "comments": [ { "id": 11, "body": "…", "person": "Avery", "quote": "ships behind a flag",
                  "prefix": "…", "suffix": "…", "startOffset": 26,
                  "blockIndex": 1, "blockOffset": 13,
                  "placement": "exact", "confidence": 1.0, "createdAt": "…" } ] }
```

## `GET /api/v1/sites/:slug/feedback` — apex origin

Producer-authenticated (`Authorization: Bearer …`). Returns the Site's whole Feedback Thread —
every Comment across every Release, chronological.

```json
{ "site": { "slug": "first-site" },
  "comments": [ { "id": 11, "release_number": 2, "path": "index.html",
                  "quote": "ships behind a flag", "placement": "exact", "confidence": 1.0,
                  "body": "Which flag is this?", "person": "Avery", "created_at": "…" } ] }
```

Consumed by `shortbread feedback pull --site <slug>` and its `--json` form.

## Placement

`placement` is the resolution state of the Comment's Anchor against the Release it was left on.

| Value | Meaning |
|---|---|
| `exact` | The quote is at its recorded offset with corroborating context |
| `moved` | The quote was found elsewhere, with context agreement |
| `ambiguous` | Several equally-good candidates; the server refuses to choose |
| `orphaned` | The quote is gone, or survives only where its identity cannot be corroborated |
| `unanchored` | A Site-level Comment that never carried a selection |

`orphaned` and `ambiguous` still carry the reviewer's original `quote`. A Comment is never dropped
and never attached to text whose identity cannot be corroborated — the failure this product exists
to avoid.
