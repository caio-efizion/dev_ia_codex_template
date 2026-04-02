export type QueueState = 'success' | 'loading' | 'empty' | 'error'

export type QueueItem = {
  id: string
  title: string
  owner: string
  priority: 'High' | 'Medium'
  eta: string
}

export type QueueViewModel = {
  state: QueueState
  heading: string
  subtitle: string
  banner: string
  metrics: Array<{ label: string; value: string; tone: 'accent' | 'neutral' | 'warning' }>
  items: QueueItem[]
}

const successItems: QueueItem[] = [
  { id: 'Q-102', title: 'Review checkout drop-off anomaly', owner: 'Caio', priority: 'High', eta: 'Today, 14:30' },
  { id: 'Q-087', title: 'Approve mobile payment hint updates', owner: 'Ana', priority: 'Medium', eta: 'Today, 16:00' },
  { id: 'Q-076', title: 'Verify empty-state copy on dashboard', owner: 'Bia', priority: 'High', eta: 'Tomorrow, 09:00' }
]

export function resolveQueueState(search: string): QueueState {
  const state = new URLSearchParams(search).get('state')
  if (state === 'loading' || state === 'empty' || state === 'error' || state === 'success') {
    return state
  }
  return 'success'
}

export function buildQueueViewModel(state: QueueState): QueueViewModel {
  switch (state) {
    case 'loading':
      return {
        state,
        heading: 'Preparing the quality inbox',
        subtitle: 'Loading the next review batch and preserving the current filters.',
        banner: 'Sync in progress',
        metrics: [
          { label: 'Open items', value: '--', tone: 'neutral' },
          { label: 'High priority', value: '--', tone: 'warning' },
          { label: 'Updated now', value: 'yes', tone: 'accent' }
        ],
        items: []
      }
    case 'empty':
      return {
        state,
        heading: 'No active findings right now',
        subtitle: 'The queue is clear. Use this moment to audit archived work or refresh benchmarks.',
        banner: 'Everything is up to date',
        metrics: [
          { label: 'Open items', value: '0', tone: 'accent' },
          { label: 'High priority', value: '0', tone: 'neutral' },
          { label: 'Updated now', value: '2m ago', tone: 'neutral' }
        ],
        items: []
      }
    case 'error':
      return {
        state,
        heading: 'The inbox could not be refreshed',
        subtitle: 'The queue service returned an unstable response. Keep the last approved state and retry safely.',
        banner: 'Refresh blocked',
        metrics: [
          { label: 'Open items', value: '3', tone: 'warning' },
          { label: 'High priority', value: '2', tone: 'warning' },
          { label: 'Updated now', value: 'offline', tone: 'neutral' }
        ],
        items: []
      }
    case 'success':
    default:
      return {
        state: 'success',
        heading: 'Operations quality inbox',
        subtitle: 'A compact queue for decisions that affect accessibility, visual polish, and flow reliability.',
        banner: 'Last sync completed 2 minutes ago',
        metrics: [
          { label: 'Open items', value: '12', tone: 'accent' },
          { label: 'High priority', value: '4', tone: 'warning' },
          { label: 'Team on review', value: '3', tone: 'neutral' }
        ],
        items: successItems
      }
  }
}
