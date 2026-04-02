import { describe, expect, it } from 'vitest'
import { renderQueueApp } from '../src/app'
import { buildQueueViewModel } from '../src/state'

describe('renderQueueApp', () => {
  it('renders the success state with labeled controls and list items', () => {
    const node = renderQueueApp(buildQueueViewModel('success'))
    expect(node.querySelector('h1')?.textContent).toContain('Operations quality inbox')
    expect(node.querySelector('label')?.textContent).toContain('Search findings')
    expect(node.querySelectorAll('li')).toHaveLength(3)
  })

  it('renders loading feedback with skeleton cards', () => {
    const node = renderQueueApp(buildQueueViewModel('loading'))
    expect(node.textContent).toContain('Loading the latest review batch.')
    expect(node.querySelectorAll('[aria-hidden="true"]')).toHaveLength(3)
  })

  it('renders an error alert and recovery action', () => {
    const node = renderQueueApp(buildQueueViewModel('error'))
    expect(node.querySelector('[role="alert"]')?.textContent).toContain('Refresh blocked')
    expect(node.textContent).toContain('Retry refresh')
  })
})
