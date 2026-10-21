// Copyright 2026 Benjamin Touchard (Kolapsis)
// SPDX-License-Identifier: Apache-2.0

// Acceptance tests of 047-audit-small-fixes, C13: braces is pinned past GHSA-vfj7-8cjw-p6xm.

import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, it, expect } from 'vitest'

type Version = [number, number, number]

const fixedBraces: Version = [3, 0, 3]

function readJSON<T>(file: string): T {
  return JSON.parse(readFileSync(resolve(__dirname, '..', file), 'utf8')) as T
}

/** The lowest version a caret, tilde, >= or exact range admits. */
function lowerBound(range: string): Version {
  const m = /^(?:\^|~|>=)?\s*(\d+)\.(\d+)\.(\d+)/.exec(range.trim())
  expect(m, `${range} is not a version range`).not.toBeNull()
  return [Number(m![1]), Number(m![2]), Number(m![3])]
}

function atLeast(v: Version, min: Version): boolean {
  for (let i = 0; i < 3; i++) {
    if (v[i] !== min[i]) return v[i]! > min[i]!
  }
  return true
}

describe('braces (GHSA-vfj7-8cjw-p6xm)', () => {
  // FR-008, US3 scenario 4: package.json constrains braces to a fixed version.
  it('is constrained in package.json overrides', () => {
    const pkg = readJSON<{ overrides?: Record<string, string> }>('package.json')
    const range = pkg.overrides?.braces
    expect(typeof range, 'overrides.braces must be set').toBe('string')
    expect(atLeast(lowerBound(range!), fixedBraces), `${range} admits a vulnerable braces`).toBe(true)
  })

  // FR-008: nothing installed is below the fixed version.
  it('installs no vulnerable braces', () => {
    const lock = readJSON<{ packages: Record<string, { version?: string }> }>('package-lock.json')
    const installed = Object.entries(lock.packages).filter(([path]) => /(^|\/)node_modules\/braces$/.test(path))
    expect(installed.length).toBeGreaterThan(0)
    for (const [path, entry] of installed) {
      expect(atLeast(lowerBound(entry.version ?? '0.0.0'), fixedBraces), `${path} is ${entry.version}`).toBe(true)
    }
  })
})
