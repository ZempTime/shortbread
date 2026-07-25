/**
 * Maps a live browser `Selection` onto an offset in extracted text, so the Anchor a reviewer
 * produces is the same one the server can verify against the Release's stored bytes.
 *
 * Three rules come from the browser-capture spike and are cheap here, expensive to retrofit:
 *
 *  1. The quote is taken from the EXTRACTION, never from `selection.toString()`. The browser
 *     reports `"\n\n"` at a block boundary where extraction has a single synthesised `\n`, so
 *     the browser's string would not round-trip.
 *  2. Selection direction is normalised. On a backwards drag `anchorNode` follows `focusNode`,
 *     so the mapped endpoints are min/maxed rather than assumed to be in order.
 *  3. Endpoints move inward onto real content. A DOM position inside a collapsed whitespace run
 *     has no 1:1 character in extracted text; a start takes the first extracted character at or
 *     after it, an end the last at or before it.
 */

import { capture as captureAnchor, type Anchor } from './anchoring'
import { fromDom, type Extracted } from './extraction'

export type SelectionPoint = { node: Node; offset: number }

/** A position already resolved down to the text node that actually holds the character. */
type TextPoint = { node: Text; offset: number }

export const captureFromSelection = ({
  root,
  selection,
  releaseNumber,
  path,
}: {
  root: Node
  selection: Selection | null
  releaseNumber: number
  path: string
}): Anchor | null => {
  if (!selection || selection.rangeCount === 0 || selection.isCollapsed) return null

  const extracted = fromDom(root)
  const range = selection.getRangeAt(0)

  const start = textOffsetAt(extracted, { node: range.startContainer, offset: range.startOffset }, 'start')
  const end = textOffsetAt(extracted, { node: range.endContainer, offset: range.endOffset }, 'end')
  if (start === null || end === null) return null

  // A backwards drag reports its endpoints reversed; `Range` normalises them, but a caller
  // building points by hand may not, so order defensively rather than assuming.
  const startOffset = Math.min(start, end)
  const endOffset = Math.max(start, end)
  if (endOffset <= startOffset) return null

  return captureAnchor({
    source: extracted.text,
    startOffset,
    length: endOffset - startOffset,
    releaseNumber,
    path,
  })
}

/**
 * The extracted-text offset a DOM position corresponds to. `start` rounds forward onto the first
 * real character at or after the position; `end` rounds backward past it, yielding an exclusive
 * bound.
 */
export const textOffsetAt = (
  extracted: Extracted,
  point: SelectionPoint,
  edge: 'start' | 'end',
): number | null => {
  const node = resolveTextNode(point, edge)
  if (!node) return null

  if (edge === 'start') {
    for (let index = 0; index < extracted.map.length; index += 1) {
      const entry = extracted.map[index]
      if (entry.node === node.node && entry.offset >= node.offset) return index
    }
    // Nothing at or after this position: the selection starts past the node's last mapped
    // character, so it belongs at the first character of whatever follows.
    return firstOffsetAfter(extracted, node.node)
  }

  for (let index = extracted.map.length - 1; index >= 0; index -= 1) {
    const entry = extracted.map[index]
    if (entry.node === node.node && entry.offset < node.offset) return index + 1
  }
  return lastOffsetBefore(extracted, node.node)
}

/**
 * A selection endpoint may land on an element rather than a text node, in which case `offset` is
 * a child index. Descend to the text node the position actually names.
 */
const resolveTextNode = (point: SelectionPoint, edge: 'start' | 'end'): TextPoint | null => {
  if (point.node.nodeType === Node.TEXT_NODE) return { node: point.node as Text, offset: point.offset }

  if (point.node.nodeType !== Node.ELEMENT_NODE) return null

  const children = Array.from(point.node.childNodes)
  const candidates = edge === 'start' ? children.slice(point.offset) : children.slice(0, point.offset).reverse()

  for (const child of candidates) {
    const found = edge === 'start' ? firstTextNode(child) : lastTextNode(child)
    if (found) return { node: found, offset: edge === 'start' ? 0 : found.data.length }
  }
  return null
}

const firstTextNode = (node: Node): Text | null => {
  if (node.nodeType === Node.TEXT_NODE) return node as Text

  for (const child of Array.from(node.childNodes)) {
    const found = firstTextNode(child)
    if (found) return found
  }
  return null
}

const lastTextNode = (node: Node): Text | null => {
  if (node.nodeType === Node.TEXT_NODE) return node as Text

  const children = Array.from(node.childNodes).reverse()
  for (const child of children) {
    const found = lastTextNode(child)
    if (found) return found
  }
  return null
}

const firstOffsetAfter = (extracted: Extracted, node: Text): number | null => {
  const index = extracted.map.findIndex((entry) => entry.node === node)
  if (index === -1) return null

  for (let cursor = index; cursor < extracted.map.length; cursor += 1) {
    if (extracted.map[cursor].node !== node) return cursor
  }
  return extracted.map.length
}

const lastOffsetBefore = (extracted: Extracted, node: Text): number | null => {
  const index = extracted.map.findIndex((entry) => entry.node === node)
  return index === -1 ? null : index
}
