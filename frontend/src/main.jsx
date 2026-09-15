import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@picocss/pico/css/pico.purple.min.css'
import App from './App.jsx'

createRoot(document.getElementById('root')).render(
  <StrictMode>
      <main className="container"><App /></main>
  </StrictMode>,
)
