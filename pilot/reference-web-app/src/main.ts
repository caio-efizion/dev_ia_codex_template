import './style.css'
import { renderQueueApp } from './app'
import { buildQueueViewModel, resolveQueueState } from './state'

const root = document.querySelector<HTMLDivElement>('#app')
if (!root) {
  throw new Error('Application root not found')
}

const state = resolveQueueState(window.location.search)
const model = buildQueueViewModel(state)
root.replaceChildren(renderQueueApp(model))
