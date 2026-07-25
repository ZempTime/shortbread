/**
 * The Viewer's review surface: select text, leave a Comment, see it repainted on reload.
 *
 * Injected into a served Release document, so it runs against the document's own DOM rather than
 * inside a React tree. It never rewrites the document's text — highlights are painted with
 * ranges so the extracted text, and therefore every Anchor offset, stays exactly as served.
 */

import { captureFromSelection } from './capture'
import { fromDom } from './extraction'
import { resolve, type Anchor, type AnchorStatus } from './anchoring'

type StoredComment = {
  id: number
  body: string
  person: string
  quote: string | null
  prefix: string | null
  suffix: string | null
  startOffset: number | null
  blockIndex: number | null
  blockOffset: number | null
  placement: AnchorStatus
}

const ENDPOINT = '/_shortbread/comments'
const HIGHLIGHT_CLASS = 'shortbread-comment-highlight'

const documentPath = (): string => {
  const path = window.location.pathname.replace(/^\//, '')
  return path === '' ? 'index.html' : path
}

/**
 * The Release this document was served from, stamped onto the script tag at serve time. An Anchor
 * is Release-scoped, so capturing one against a guessed Release number would record a value the
 * PRD calls immutable as a lie — even though the server re-derives the real one on write.
 */
const releaseNumber = (): number => {
  const stamped = document.querySelector('script[data-shortbread-release]')
  return Number(stamped?.getAttribute('data-shortbread-release') ?? 0)
}

const styles = `
  .${HIGHLIGHT_CLASS} { background: rgba(250, 204, 21, 0.4); cursor: pointer; }
  .shortbread-review-panel {
    position: fixed; top: 0; right: 0; bottom: 0; width: 320px; overflow-y: auto;
    background: #fff; border-left: 1px solid #e5e7eb; padding: 16px; z-index: 2147483000;
    font: 14px/1.5 system-ui, sans-serif; color: #111827;
  }
  .shortbread-review-panel h2 { font-size: 13px; text-transform: uppercase; letter-spacing: .05em;
    color: #6b7280; margin: 0 0 12px; }
  .shortbread-comment { border-top: 1px solid #f3f4f6; padding: 12px 0; }
  .shortbread-comment blockquote { margin: 0 0 6px; padding-left: 8px;
    border-left: 3px solid #facc15; color: #4b5563; font-style: italic; }
  .shortbread-comment .meta { color: #6b7280; font-size: 12px; margin-top: 4px; }
  .shortbread-comment.orphaned blockquote { border-left-color: #d1d5db; }
  .shortbread-composer { position: absolute; z-index: 2147483100; background: #fff;
    border: 1px solid #d1d5db; border-radius: 6px; padding: 8px; width: 260px;
    box-shadow: 0 4px 12px rgba(0,0,0,.15); }
  .shortbread-composer textarea { width: 100%; min-height: 60px; font: inherit;
    border: 1px solid #d1d5db; border-radius: 4px; padding: 6px; box-sizing: border-box; }
  .shortbread-composer button { margin-top: 6px; font: inherit; padding: 4px 10px;
    border-radius: 4px; border: 1px solid #2563eb; background: #2563eb; color: #fff;
    cursor: pointer; }
`

const install = (): void => {
  const style = document.createElement('style')
  style.textContent = styles
  document.head.append(style)

  const panel = document.createElement('aside')
  panel.className = 'shortbread-review-panel'
  panel.innerHTML = '<h2>Comments</h2>'
  document.body.append(panel)

  void refresh(panel)
  document.addEventListener('mouseup', () => void onSelection(panel))
}

/** The document root the Anchor is captured against — the panel is never part of it. */
const contentRoot = (): HTMLElement => document.body

const onSelection = async (panel: HTMLElement): Promise<void> => {
  document.querySelector('.shortbread-composer')?.remove()

  const selection = window.getSelection()
  if (!selection || selection.isCollapsed) return
  if (selection.anchorNode && panelContains(selection.anchorNode)) return

  const anchor = captureFromSelection({
    root: contentRoot(),
    selection,
    releaseNumber: releaseNumber(),
    path: documentPath(),
  })
  if (!anchor) return

  openComposer(anchor, selection, panel)
}

const panelContains = (node: Node): boolean =>
  Boolean(document.querySelector('.shortbread-review-panel')?.contains(node))

const openComposer = (anchor: Anchor, selection: Selection, panel: HTMLElement): void => {
  const rect = selection.getRangeAt(0).getBoundingClientRect()
  const composer = document.createElement('div')
  composer.className = 'shortbread-composer'
  composer.style.top = `${rect.bottom + window.scrollY + 6}px`
  composer.style.left = `${rect.left + window.scrollX}px`

  const textarea = document.createElement('textarea')
  textarea.placeholder = 'Leave a comment…'
  const submit = document.createElement('button')
  submit.textContent = 'Comment'

  submit.addEventListener('click', () => {
    const body = textarea.value.trim()
    if (!body) return

    submit.disabled = true
    void post(anchor, body)
      .then(() => {
        composer.remove()
        return refresh(panel)
      })
      .catch(() => {
        submit.disabled = false
        submit.textContent = 'Failed — retry'
      })
  })

  composer.append(textarea, submit)
  document.body.append(composer)
  textarea.focus()
}

const post = async (anchor: Anchor, body: string): Promise<void> => {
  const response = await fetch(ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      body,
      path: anchor.path,
      quote: anchor.quote,
      start_offset: anchor.startOffset,
    }),
  })
  if (!response.ok) throw new Error(`comment rejected: ${response.status}`)
}

const refresh = async (panel: HTMLElement): Promise<void> => {
  const response = await fetch(`${ENDPOINT}?path=${encodeURIComponent(documentPath())}`)
  if (!response.ok) return

  const payload = (await response.json()) as { comments: StoredComment[] }
  paint(payload.comments)
  render(panel, payload.comments)
}

/**
 * Repaint each Comment on the text it was anchored to. Resolution runs client-side against the
 * same extraction the server verified against, so a Comment whose text moved is still found and
 * one whose text is gone is reported rather than silently dropped.
 */
export const paint = (comments: StoredComment[], root: HTMLElement = contentRoot()): void => {
  for (const highlight of Array.from(root.querySelectorAll(`.${HIGHLIGHT_CLASS}`))) {
    highlight.replaceWith(...Array.from(highlight.childNodes))
  }

  const extracted = fromDom(root)

  for (const comment of comments) {
    if (comment.startOffset === null || !comment.quote) continue

    const resolution = resolve(
      {
        releaseNumber: releaseNumber(),
        path: documentPath(),
        quote: comment.quote,
        prefix: comment.prefix ?? '',
        suffix: comment.suffix ?? '',
        startOffset: comment.startOffset,
        blockIndex: comment.blockIndex,
        blockOffset: comment.blockOffset,
      },
      extracted.text,
    )
    if (resolution.startOffset === null || resolution.endOffset === null) continue

    highlight(extracted, resolution.startOffset, resolution.endOffset, comment)
  }
}

const highlight = (
  extracted: ReturnType<typeof fromDom>,
  startOffset: number,
  endOffset: number,
  comment: StoredComment,
): void => {
  // One mark per text node the quote touches, rather than one range across the whole span.
  // `surroundContents` refuses a range that partially selects an element, and a quote crossing
  // inline markup — `<em>`, a link — does exactly that, so a single range would silently fail to
  // paint the most ordinary kind of selection there is.
  for (const [node, span] of spansByNode(extracted, startOffset, endOffset)) {
    try {
      const range = document.createRange()
      range.setStart(node, span.start)
      range.setEnd(node, span.end)

      const mark = document.createElement('mark')
      mark.className = HIGHLIGHT_CLASS
      mark.dataset.commentId = String(comment.id)
      range.surroundContents(mark)
    } catch {
      /* the Comment remains listed in the panel even where it cannot be painted in place */
    }
  }
}

/**
 * The UTF-16 span each text node contributes to one extracted-text range.
 *
 * `map` holds UTF-16 offsets into a node while extraction offsets are code points, so each end
 * advances by the width of its own code point. Assuming 1 clips an astral character mid-surrogate,
 * which throws and drops the highlight.
 */
const spansByNode = (
  extracted: ReturnType<typeof fromDom>,
  startOffset: number,
  endOffset: number,
): Map<Text, { start: number; end: number }> => {
  const spans = new Map<Text, { start: number; end: number }>()

  for (let offset = startOffset; offset < endOffset; offset += 1) {
    const entry = extracted.map[offset]
    if (!entry) continue

    const codePoint = entry.node.data.codePointAt(entry.offset)
    const width = codePoint !== undefined && codePoint > 0xffff ? 2 : 1
    const existing = spans.get(entry.node)

    if (existing) {
      existing.start = Math.min(existing.start, entry.offset)
      existing.end = Math.max(existing.end, entry.offset + width)
    } else {
      spans.set(entry.node, { start: entry.offset, end: entry.offset + width })
    }
  }

  return spans
}

const render = (panel: HTMLElement, comments: StoredComment[]): void => {
  panel.innerHTML = '<h2>Comments</h2>'

  for (const comment of comments) {
    const item = document.createElement('div')
    item.className = `shortbread-comment${comment.placement === 'orphaned' ? ' orphaned' : ''}`

    if (comment.quote) {
      const quote = document.createElement('blockquote')
      quote.textContent = comment.quote
      item.append(quote)
    }

    const body = document.createElement('p')
    body.textContent = comment.body
    body.style.margin = '0'

    const meta = document.createElement('p')
    meta.className = 'meta'
    meta.textContent =
      comment.placement === 'exact' ? comment.person : `${comment.person} · ${comment.placement}`

    item.append(body, meta)
    panel.append(item)
  }
}

// The surface installs itself when injected into a served document. A harness that only wants
// the painting logic sets this flag first, so importing the module does not build a panel.
declare global {
  interface Window {
    shortbreadReviewSurfaceManualInstall?: boolean
  }
}

if (!window.shortbreadReviewSurfaceManualInstall) {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', install)
  } else {
    install()
  }
}
