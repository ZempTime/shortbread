/**
 * The TypeScript half of the shared conformance matrix. Its Ruby twin at
 * test/lib/shortbread/anchoring_conformance_test.rb drives the SAME fixture file and asserts the
 * same expectations, so a disagreement between the two implementations fails a suite rather than
 * silently producing Anchors the server cannot verify.
 */

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

import { capture, resolve, type AnchorStatus } from '../../app/frontend/anchoring/anchoring.ts'

type ResolutionFixture = {
  name: string
  source: string
  quote: string
  occurrence: number
  republished: string
  status: AnchorStatus
}

const here = dirname(fileURLToPath(import.meta.url))
const fixtures = JSON.parse(readFileSync(join(here, 'conformance_fixtures.json'), 'utf8')) as {
  resolution: ResolutionFixture[]
}

const points = (text: string): string[] => Array.from(text)

/** Code-point index of the nth occurrence, matching how Ruby counts. */
const nthIndex = (source: string, quote: string, occurrence: number): number => {
  const haystack = points(source)
  const needle = points(quote)
  let seen = -1

  for (let index = 0; index <= haystack.length - needle.length; index += 1) {
    if (needle.every((character, offset) => haystack[index + offset] === character)) {
      seen += 1
      if (seen === occurrence) return index
    }
  }
  throw new Error(`quote not found: ${quote}`)
}

const anchorFor = (fixture: ResolutionFixture) =>
  capture({
    source: fixture.source,
    startOffset: nthIndex(fixture.source, fixture.quote, fixture.occurrence),
    length: points(fixture.quote).length,
    releaseNumber: 1,
    path: 'index.html',
  })

test('resolution reports the shared fixture status for every case', () => {
  for (const fixture of fixtures.resolution) {
    const resolution = resolve(anchorFor(fixture), fixture.republished)

    assert.equal(resolution.status, fixture.status, fixture.name)
  }
})

test('a resolved offset always points at the anchored quote', () => {
  for (const fixture of fixtures.resolution) {
    const anchor = anchorFor(fixture)
    const resolution = resolve(anchor, fixture.republished)
    if (resolution.startOffset === null || resolution.endOffset === null) continue

    const found = points(fixture.republished)
      .slice(resolution.startOffset, resolution.endOffset)
      .join('')
    assert.equal(found, anchor.quote, `${fixture.name}: resolved offset does not hold the quote`)
  }
})

test('an astral character counts as one code point, matching Ruby', () => {
  const source = 'Ship 😀 it.\nThe build must stay green.'
  const quote = 'The build must stay green'
  const startOffset = nthIndex(source, quote, 0)

  // Ruby reports 11 here; a UTF-16 count would report 12 and desync every later offset.
  assert.equal(startOffset, 11)
  assert.notEqual(startOffset, source.indexOf(quote))

  const anchor = capture({ source, startOffset, length: points(quote).length, releaseNumber: 1, path: 'index.html' })
  assert.equal(anchor.quote, quote)
  assert.equal(resolve(anchor, source).status, 'exact')
})

test('a Comment on deleted text orphans rather than relocating onto an identical string', () => {
  const source = 'Section one.\nThe build must stay green.\nSection two.\nThe build must stay green.\nSection three.'
  const quote = 'The build must stay green'
  const anchor = capture({
    source,
    startOffset: nthIndex(source, quote, 1),
    length: points(quote).length,
    releaseNumber: 1,
    path: 'index.html',
  })

  const resolution = resolve(anchor, source.replace('Section two.\nThe build must stay green.\n', 'Section two.\n'))

  assert.equal(resolution.status, 'orphaned')
  assert.equal(resolution.startOffset, null)
})

test('an empty quote is orphaned rather than matching everywhere', () => {
  const anchor = capture({ source: 'Anything.', startOffset: 0, length: 0, releaseNumber: 1, path: 'index.html' })

  assert.equal(resolve(anchor, 'Anything.').status, 'orphaned')
})
