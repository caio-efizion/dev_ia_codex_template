import { beforeEach, describe, expect, it, vi } from 'vitest'

describe('main entrypoint', () => {
  beforeEach(() => {
    vi.resetModules()
    document.body.innerHTML = '<div id="app"></div>'
  })

  it('mounts the empty state from the URL search params', async () => {
    window.history.replaceState({}, '', '/?state=empty')
    await import('../src/main')
    expect(document.body.textContent).toContain('Queue clear')
  })
})
