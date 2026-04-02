import { expect, test } from '@playwright/test'

test('renders the success queue by default', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Operations quality inbox' })).toBeVisible()
  await expect(page.getByLabel('Search findings')).toBeVisible()
  await expect(page.getByRole('list', { name: 'Open quality findings' })).toBeVisible()
})

test('renders loading feedback', async ({ page }) => {
  await page.goto('/?state=loading')
  await expect(page.getByText('Loading the latest review batch.')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Refresh queue' })).toBeDisabled()
})

test('renders empty state recovery', async ({ page }) => {
  await page.goto('/?state=empty')
  await expect(page.getByRole('heading', { name: 'Queue clear' })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Review archive' })).toBeVisible()
})

test('renders error alert', async ({ page }) => {
  await page.goto('/?state=error')
  await expect(page.getByRole('alert')).toContainText('Refresh blocked')
  await expect(page.getByRole('button', { name: 'Retry refresh' })).toBeVisible()
})
