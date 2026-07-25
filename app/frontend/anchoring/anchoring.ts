/**
 * The TypeScript twin of `Shortbread::Anchoring`. Resolution must agree with the Ruby
 * implementation exactly — the conformance suite drives both over one fixture set and diffs the
 * results, because a silent disagreement here means an Anchor captured in the browser fails to
 * verify server-side.
 *
 * Offsets are Unicode CODE POINTS, not UTF-16 code units. Ruby counts code points natively and
 * the server is what verifies an Anchor against stored bytes, so the server's unit is canonical.
 * One astral character (an emoji) is 1 code point but 2 UTF-16 units, so counting the JavaScript
 * way would desync every offset after it. All conversion happens at the DOM boundary in
 * `capture.ts`; this module works purely in code-point space.
 */

export const CONTEXT_LEN = 32

export type AnchorStatus = 'exact' | 'moved' | 'ambiguous' | 'orphaned'

export type Anchor = {
  releaseNumber: number
  path: string
  quote: string
  prefix: string
  suffix: string
  startOffset: number
  blockIndex: number | null
  blockOffset: number | null
}

export type Resolution = {
  status: AnchorStatus
  startOffset: number | null
  endOffset: number | null
  confidence: number
  note: string
  candidates: number[]
}

/** Code points, so offsets mean the same thing here as they do in Ruby. */
const points = (text: string): string[] => Array.from(text)

const pointLength = (text: string): number => points(text).length

const slice = (text: string, start: number, end?: number): string =>
  points(text)
    .slice(start, end)
    .join('')

const sliceLength = (text: string, start: number, length: number): string =>
  slice(text, start, start + length)

export const capture = ({
  source,
  startOffset,
  length,
  releaseNumber,
  path,
}: {
  source: string
  startOffset: number
  length: number
  releaseNumber: number
  path: string
}): Anchor => {
  const [blockIndex, blockOffset] = blockPosition(source, startOffset)

  return {
    releaseNumber,
    path,
    quote: sliceLength(source, startOffset, length),
    prefix: slice(source, Math.max(startOffset - CONTEXT_LEN, 0), startOffset),
    suffix: sliceLength(source, startOffset + length, CONTEXT_LEN),
    startOffset,
    blockIndex,
    blockOffset,
  }
}

/**
 * Ordered tiers, each reporting how it succeeded. Failure is a first-class `orphaned` result,
 * never a dropped highlight and never a guess.
 */
export const resolve = (anchor: Anchor, source: string): Resolution => {
  if (!anchor.quote) return orphaned('quote is empty')

  const occurrences = allOccurrences(source, anchor.quote)
  if (occurrences.length === 0) return orphaned('quote no longer appears in this document')

  return resolveAtRecordedOffset(anchor, source, occurrences) ?? resolveByContext(anchor, source, occurrences)
}

/**
 * Tier 1 — the quote still sits at the recorded offset with both context sides agreeing. Offset
 * alone is not enough: if another occurrence scores just as well, the recorded offset is a
 * coin-flip that happened to be right once, so only claim `exact` when it is uniquely best.
 */
const resolveAtRecordedOffset = (
  anchor: Anchor,
  source: string,
  occurrences: number[],
): Resolution | null => {
  if (!occurrences.includes(anchor.startOffset)) return null
  if (contextScore(anchor, source, anchor.startOffset) !== 2) return null

  const rivals = occurrences
    .filter((offset) => offset !== anchor.startOffset)
    .filter((offset) => contextScore(anchor, source, offset) === 2)
  const uniquelyBest =
    rivals.length === 0 ||
    sameOffsets(structuralTiebreak(anchor, source, [anchor.startOffset, ...rivals]), [anchor.startOffset])
  if (!uniquelyBest) return null

  return {
    status: 'exact',
    startOffset: anchor.startOffset,
    endOffset: anchor.startOffset + pointLength(anchor.quote),
    confidence: 1.0,
    note: 'offset and both context sides match, uniquely',
    candidates: occurrences,
  }
}

/**
 * Tier 2 — score every occurrence by context agreement, break ties structurally. Handles both
 * "an earlier paragraph was edited" and "the string appears five times".
 */
const resolveByContext = (anchor: Anchor, source: string, occurrences: number[]): Resolution => {
  const scored = occurrences.map((offset) => [offset, contextScore(anchor, source, offset)] as const)
  const best = Math.max(...scored.map(([, score]) => score))
  let winners = scored.filter(([, score]) => score === best).map(([offset]) => offset)
  if (winners.length > 1) winners = structuralTiebreak(anchor, source, winners)

  if (winners.length > 1) {
    // Same quote, same context, no structural separation. Proximity is only a legitimate
    // tie-break when the document still corroborates the anchor's own offset.
    if (!winners.includes(anchor.startOffset)) return ambiguous(winners, best)
    winners = [anchor.startOffset]
  }

  const offset = winners[0]

  // A surviving occurrence is not evidence that it is the SAME occurrence. With no context
  // agreement and the text moved, the reviewer's sentence may have been deleted and this is a
  // different instance of the same string. A Comment parked in a tray is recoverable; one
  // silently attached to the wrong paragraph is not.
  if (best === 0 && offset !== anchor.startOffset) {
    return {
      status: 'orphaned',
      startOffset: null,
      endOffset: null,
      confidence: 0.0,
      note: 'quote still present but all surrounding context changed — cannot confirm identity',
      candidates: occurrences,
    }
  }

  return placed(anchor, offset, best, occurrences)
}

const placed = (
  anchor: Anchor,
  offset: number,
  contextSides: number,
  occurrences: number[],
): Resolution => {
  const confidence = 0.5 + contextSides * 0.25
  const endOffset = offset + pointLength(anchor.quote)

  if (offset === anchor.startOffset && contextSides > 0) {
    return {
      status: 'exact',
      startOffset: offset,
      endOffset,
      confidence,
      note: `offset unchanged, ${contextSides}/2 context sides match`,
      candidates: occurrences,
    }
  }

  return {
    status: 'moved',
    startOffset: offset,
    endOffset,
    confidence,
    note: `text found at ${offset} (was ${anchor.startOffset}), ${contextSides}/2 context sides match`,
    candidates: occurrences,
  }
}

export const allOccurrences = (source: string, quote: string): number[] => {
  const haystack = points(source)
  const needle = points(quote)
  const found: number[] = []
  if (needle.length === 0) return found

  for (let index = 0; index <= haystack.length - needle.length; index += 1) {
    if (needle.every((character, offset) => haystack[index + offset] === character)) found.push(index)
  }
  return found
}

/** 0, 1, or 2 — how many context sides still agree at this candidate offset. */
export const contextScore = (anchor: Anchor, source: string, offset: number): number => {
  let score = 0

  if (anchor.prefix) {
    const actual = slice(source, Math.max(offset - pointLength(anchor.prefix), 0), offset)
    if (actual === anchor.prefix) score += 1
  }

  if (anchor.suffix) {
    const start = offset + pointLength(anchor.quote)
    const actual = sliceLength(source, start, pointLength(anchor.suffix))
    if (actual === anchor.suffix) score += 1
  }

  return score
}

const blocks = (source: string): Array<[number, string]> => {
  const found: Array<[number, string]> = []
  let offset = 0

  for (const chunk of source.split(/(\n[ \t]*\n|\n)/)) {
    if (chunk.trim() !== '') found.push([offset, chunk])
    offset += pointLength(chunk)
  }
  return found
}

export const blockPosition = (source: string, offset: number): [number | null, number | null] => {
  const found = blocks(source)

  for (let index = 0; index < found.length; index += 1) {
    const [start, text] = found[index]
    if (offset >= start && offset < start + pointLength(text)) return [index, offset - start]
  }
  return [null, null]
}

const structuralTiebreak = (anchor: Anchor, source: string, offsets: number[]): number[] => {
  if (anchor.blockIndex === null) return offsets

  const sameBlock = offsets.filter((offset) => blockPosition(source, offset)[0] === anchor.blockIndex)
  return sameBlock.length === 0 ? offsets : sameBlock
}

const sameOffsets = (left: number[], right: number[]): boolean =>
  left.length === right.length && left.every((value, index) => value === right[index])

const ambiguous = (winners: number[], contextSides: number): Resolution => ({
  status: 'ambiguous',
  startOffset: null,
  endOffset: null,
  confidence: 0.0,
  note: `${winners.length} equally-good candidates (context ${contextSides}/2), no way to choose`,
  candidates: winners,
})

const orphaned = (note: string): Resolution => ({
  status: 'orphaned',
  startOffset: null,
  endOffset: null,
  confidence: 0.0,
  note,
  candidates: [],
})
