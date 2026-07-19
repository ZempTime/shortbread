import { createInertiaApp } from '@inertiajs/react'

void createInertiaApp({
  pages: '../pages',
  strictMode: true,
}).catch((error: unknown) => {
  if (document.getElementById('app')) throw error
})
