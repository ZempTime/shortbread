/**
 * The TypeScript twin of `Shortbread::Extraction`, walking the DOM instead of scanning bytes.
 *
 * Visibility is decided by TAG NAME ONLY. `innerText`, `getClientRects`, and every other
 * CSS-aware test are deliberately avoided: they would drop `display:none` text that the Ruby
 * extractor keeps, and a measured 19-character divergence on one hidden block silently breaks
 * server-side verification for every Anchor after it. Emitting hidden text is harmless because
 * both sides do it identically — it is the agreement that matters, not the visibility.
 *
 * Offsets are Unicode code points, matching Ruby. A DOM node's `textContent` is UTF-16, so every
 * boundary crossing converts.
 */

export type Extracted = {
  text: string
  /** For each extracted code point, the DOM node and UTF-16 offset within it that produced it. */
  map: Array<{ node: Text; offset: number }>
}

const INVISIBLE = new Set(['script', 'style', 'head', 'title', 'meta', 'link'])

const BLOCK = new Set([
  'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'tr', 'br', 'hr', 'section', 'article',
  'header', 'footer', 'pre', 'blockquote', 'table', 'thead', 'tbody', 'td', 'th', 'ul', 'ol',
])

type State = {
  text: string[]
  map: Array<{ node: Text; offset: number }>
  preDepth: number
}

export const fromDom = (root: Node): Extracted => {
  const state: State = { text: [], map: [], preDepth: 0 }
  walk(root, state)
  return trimmed(state)
}

const walk = (node: Node, state: State): void => {
  if (node.nodeType === Node.TEXT_NODE) {
    appendText(node as Text, state)
    return
  }

  if (node.nodeType !== Node.ELEMENT_NODE) return

  const element = node as Element
  const name = element.tagName.toLowerCase()
  if (INVISIBLE.has(name)) return

  const isPre = name === 'pre'
  const isBlock = BLOCK.has(name)

  // Both ENTERING and LEAVING a block break the text. Breaking only on entering lets the
  // whitespace after `</h1>` survive as a space and desyncs every subsequent offset — the exact
  // divergence the browser spike found on its first run.
  if (isBlock) breakBlock(state)
  if (isPre) state.preDepth += 1

  for (const child of Array.from(element.childNodes)) walk(child, state)

  if (isPre) state.preDepth = Math.max(0, state.preDepth - 1)
  if (isBlock) breakBlock(state)
}

const breakBlock = (state: State): void => {
  if (state.text.length === 0) return
  if (state.text[state.text.length - 1] === '\n') return

  state.text.push('\n')
  // A synthesised break corresponds to a tag rather than to any selectable character. It is
  // anchored to the last real position so a selection landing here still maps somewhere sane.
  state.map.push(state.map[state.map.length - 1])
}

const appendText = (node: Text, state: State): void => {
  const content = node.data
  let utf16Offset = 0

  for (const character of content) {
    if (/\s/.test(character)) {
      appendWhitespace(character, node, utf16Offset, state)
    } else {
      state.text.push(character)
      state.map.push({ node, offset: utf16Offset })
    }
    utf16Offset += character.length
  }
}

/**
 * Runs of whitespace collapse to a single space the way a browser renders them — except inside
 * `<pre>`, where whitespace is content.
 */
const appendWhitespace = (
  character: string,
  node: Text,
  utf16Offset: number,
  state: State,
): void => {
  if (state.preDepth > 0) {
    state.text.push(character)
    state.map.push({ node, offset: utf16Offset })
    return
  }

  const last = state.text[state.text.length - 1]
  if (state.text.length === 0 || last === ' ' || last === '\n') return

  state.text.push(' ')
  state.map.push({ node, offset: utf16Offset })
}

/**
 * Trim text and map together — trimming only the text desyncs every offset after the leading
 * whitespace, which looks exactly like anchor drift.
 */
const trimmed = (state: State): Extracted => {
  let start = 0
  let end = state.text.length
  while (start < end && /\s/.test(state.text[start])) start += 1
  while (end > start && /\s/.test(state.text[end - 1])) end -= 1

  return {
    text: state.text.slice(start, end).join(''),
    map: state.map.slice(start, end),
  }
}
