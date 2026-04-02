import { describe, expect, it } from 'vitest'
import { buildQueueViewModel, resolveQueueState } from '../src/state'

describe('resolveQueueState', () => {
  it('defaults to success for unknown values', () => {
    expect(resolveQueueState('?state=unknown')).toBe('success')
  })

  it('keeps supported explicit states', () => {
    expect(resolveQueueState('?state=loading')).toBe('loading')
    expect(resolveQueueState('?state=empty')).toBe('empty')
    expect(resolveQueueState('?state=error')).toBe('error')
    expect(resolveQueueState('?state=success')).toBe('success')
  })
})

describe('buildQueueViewModel', () => {
  it('returns a populated success model', () => {
    const model = buildQueueViewModel('success')
    expect(model.items).toHaveLength(3)
    expect(model.metrics[0]?.value).toBe('12')
  })

  it('returns an empty model for empty state', () => {
    const model = buildQueueViewModel('empty')
    expect(model.items).toHaveLength(0)
    expect(model.banner).toContain('up to date')
  })
})
