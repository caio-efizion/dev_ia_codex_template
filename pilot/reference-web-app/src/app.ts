import type { QueueItem, QueueState, QueueViewModel } from './state'

function createElement<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className?: string,
  text?: string
): HTMLElementTagNameMap[K] {
  const element = document.createElement(tag)
  if (className) {
    element.className = className
  }
  if (text) {
    element.textContent = text
  }
  return element
}

function metricToneClass(tone: QueueViewModel['metrics'][number]['tone']): string {
  switch (tone) {
    case 'accent':
      return 'bg-teal-500/15 text-teal-100 ring-1 ring-inset ring-teal-400/30'
    case 'warning':
      return 'bg-amber-500/15 text-amber-100 ring-1 ring-inset ring-amber-400/30'
    default:
      return 'bg-stone-800/90 text-stone-100 ring-1 ring-inset ring-white/8'
  }
}

function buildMetricCard(metric: QueueViewModel['metrics'][number]): HTMLDivElement {
  const card = createElement('div', `rounded-3xl p-4 shadow-lg shadow-black/10 ${metricToneClass(metric.tone)}`)
  const label = createElement('p', 'text-xs uppercase tracking-[0.24em] text-stone-300', metric.label)
  const value = createElement('p', 'mt-3 text-3xl font-semibold tracking-tight', metric.value)
  card.append(label, value)
  return card
}

function buildItem(item: QueueItem): HTMLLIElement {
  const li = createElement('li', 'rounded-3xl border border-white/10 bg-white/5 p-5 backdrop-blur-sm')
  const top = createElement('div', 'flex items-start justify-between gap-4')
  const text = createElement('div', 'space-y-1')
  const title = createElement('h3', 'text-lg font-semibold text-white', item.title)
  const owner = createElement('p', 'text-sm text-stone-300', `Owner: ${item.owner}`)
  text.append(title, owner)

  const pill = createElement(
    'span',
    item.priority === 'High'
      ? 'rounded-full bg-amber-400/15 px-3 py-1 text-xs font-semibold uppercase tracking-[0.22em] text-amber-100'
      : 'rounded-full bg-stone-200/10 px-3 py-1 text-xs font-semibold uppercase tracking-[0.22em] text-stone-100',
    item.priority
  )
  top.append(text, pill)

  const meta = createElement('p', 'mt-4 text-sm text-stone-400', `${item.id} · ETA ${item.eta}`)
  li.append(top, meta)
  return li
}

function buildLoadingGrid(): HTMLDivElement {
  const grid = createElement('div', 'grid gap-4 md:grid-cols-3')
  for (let index = 0; index < 3; index += 1) {
    const card = createElement('div', 'rounded-3xl border border-white/10 bg-white/5 p-5')
    card.setAttribute('aria-hidden', 'true')
    const lineOne = createElement('div', 'h-4 w-24 animate-pulse rounded-full bg-stone-700')
    const lineTwo = createElement('div', 'mt-4 h-8 w-20 animate-pulse rounded-full bg-stone-600')
    card.append(lineOne, lineTwo)
    grid.append(card)
  }
  return grid
}

function buildSurface(model: QueueViewModel, state: QueueState): HTMLElement {
  const surface = createElement('section', 'rounded-[2rem] border border-white/10 bg-stone-900/70 p-5 shadow-2xl shadow-black/25 backdrop-blur-xl md:p-8')
  const header = createElement('div', 'flex flex-col gap-4 border-b border-white/10 pb-6 md:flex-row md:items-end md:justify-between')
  const headingGroup = createElement('div', 'max-w-2xl')
  const eyebrow = createElement('p', 'text-xs uppercase tracking-[0.28em] text-teal-200', 'Delivery control')
  const title = createElement('h1', 'mt-3 text-3xl font-semibold tracking-tight text-white md:text-5xl', model.heading)
  const subtitle = createElement('p', 'mt-3 max-w-2xl text-sm leading-6 text-stone-300 md:text-base', model.subtitle)
  headingGroup.append(eyebrow, title, subtitle)

  const controls = createElement('div', 'grid gap-3 sm:grid-cols-[1fr_auto] sm:items-end')
  const searchWrap = createElement('div', 'space-y-2')
  const searchLabel = createElement('label', 'text-xs font-semibold uppercase tracking-[0.2em] text-stone-300', 'Search findings')
  searchLabel.htmlFor = 'queue-search'
  const search = document.createElement('input')
  search.id = 'queue-search'
  search.type = 'text'
  search.placeholder = 'Filter by title or owner'
  search.className = 'w-full rounded-2xl border border-white/10 bg-stone-950/80 px-4 py-3 text-sm text-white outline-none transition focus:border-teal-300 focus:ring-2 focus:ring-teal-300/35 disabled:cursor-not-allowed disabled:opacity-60'
  search.disabled = state === 'loading'
  searchWrap.append(searchLabel, search)

  const refresh = createElement('button', 'rounded-2xl bg-teal-300 px-5 py-3 text-sm font-semibold text-stone-950 transition hover:bg-teal-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-stone-950 focus-visible:ring-teal-200 disabled:cursor-not-allowed disabled:opacity-60', 'Refresh queue')
  refresh.setAttribute('type', 'button')
  refresh.toggleAttribute('disabled', state === 'loading')
  controls.append(searchWrap, refresh)
  header.append(headingGroup, controls)

  const banner = createElement(
    state === 'error' ? 'div' : 'p',
    state === 'error'
      ? 'mt-6 rounded-3xl border border-rose-400/25 bg-rose-500/10 px-5 py-4 text-sm text-rose-100'
      : 'mt-6 inline-flex rounded-full bg-white/6 px-4 py-2 text-sm text-stone-200 ring-1 ring-inset ring-white/8',
    model.banner
  )
  if (state === 'error') {
    banner.setAttribute('role', 'alert')
  } else {
    banner.setAttribute('role', 'status')
    banner.setAttribute('aria-live', 'polite')
  }

  const metrics = createElement('div', 'mt-6 grid gap-4 md:grid-cols-3')
  model.metrics.forEach((metric) => metrics.append(buildMetricCard(metric)))

  const filters = createElement('div', 'mt-8 flex flex-wrap gap-3')
  ;['All', 'High risk', 'Recently updated'].forEach((label, index) => {
    const button = createElement(
      'button',
      index === 0
        ? 'rounded-full border border-teal-300/40 bg-teal-400/15 px-4 py-2 text-sm font-medium text-teal-100 transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-stone-950 focus-visible:ring-teal-200'
        : 'rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-stone-200 transition hover:bg-white/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-stone-950 focus-visible:ring-teal-200',
      label
    )
    button.type = 'button'
    filters.append(button)
  })

  const content = createElement('div', 'mt-8')
  if (state === 'loading') {
    const status = createElement('p', 'mb-4 text-sm text-stone-300', 'Loading the latest review batch.')
    status.setAttribute('role', 'status')
    status.setAttribute('aria-live', 'polite')
    content.append(status, buildLoadingGrid())
  } else if (state === 'empty') {
    const emptyCard = createElement('div', 'rounded-[1.75rem] border border-dashed border-white/15 bg-white/5 px-6 py-10 text-center')
    emptyCard.append(
      createElement('h2', 'text-xl font-semibold text-white', 'Queue clear'),
      createElement('p', 'mt-3 text-sm leading-6 text-stone-300', 'No pending decisions remain. Review archived work, refresh visual baselines, or open the next discovery topic.'),
      createElement('button', 'mt-6 rounded-2xl bg-white px-4 py-3 text-sm font-semibold text-stone-950 transition hover:bg-stone-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-stone-950 focus-visible:ring-white', 'Review archive')
    )
    content.append(emptyCard)
  } else if (state === 'error') {
    const retryRow = createElement('div', 'rounded-[1.75rem] border border-rose-400/25 bg-rose-500/10 px-6 py-6')
    retryRow.append(
      createElement('h2', 'text-xl font-semibold text-white', 'Retry without losing context'),
      createElement('p', 'mt-3 text-sm leading-6 text-rose-100/90', 'The queue failed to refresh. Keep the last approved decisions visible, retry safely, and do not hide the issue from the operator.'),
      createElement('button', 'mt-6 rounded-2xl bg-rose-100 px-4 py-3 text-sm font-semibold text-rose-950 transition hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-stone-950 focus-visible:ring-rose-100', 'Retry refresh')
    )
    content.append(retryRow)
  } else {
    const list = createElement('ul', 'grid gap-4 md:grid-cols-2 xl:grid-cols-3')
    list.setAttribute('aria-label', 'Open quality findings')
    model.items.forEach((item) => list.append(buildItem(item)))
    content.append(list)
  }

  surface.append(header, banner, metrics, filters, content)
  return surface
}

export function renderQueueApp(model: QueueViewModel): HTMLElement {
  const main = createElement('main', 'mx-auto flex min-h-screen w-full max-w-7xl flex-col justify-center px-4 py-8 md:px-8 md:py-12')
  const frame = createElement('div', 'relative overflow-hidden rounded-[2.5rem] bg-stone-950/45 p-3 ring-1 ring-white/10 md:p-5')
  const accent = createElement('div', 'pointer-events-none absolute inset-x-6 top-0 h-24 rounded-full bg-teal-300/10 blur-3xl')
  frame.append(accent, buildSurface(model, model.state))
  main.append(frame)
  return main
}
