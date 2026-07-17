import React from 'react'
import ReactDOM from 'react-dom/client'
import Lanyard from './Lanyard'
import './index.css'

ReactDOM.createRoot(document.getElementById('lanyard-root')).render(
  <React.StrictMode>
    <Lanyard 
      position={[0, 0, 24]} 
      gravity={[0, -40, 0]} 
      frontImage="assets/marketing/app-icon.png"
      imageFit="contain"
    />
  </React.StrictMode>,
)
