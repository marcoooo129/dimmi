import React from 'react'
import ReactDOM from 'react-dom/client'
import Lanyard from './Lanyard'
import OptionWheelDemo from './OptionWheelDemo'

const lanyardRoot = document.getElementById('lanyard-root');
if (lanyardRoot) {
  ReactDOM.createRoot(lanyardRoot).render(
    <React.StrictMode>
      <Lanyard 
        position={[0, 0, 24]} 
        gravity={[0, -40, 0]} 
        frontImage="assets/marketing/app-icon.png"
        imageFit="contain"
      />
    </React.StrictMode>,
  )
}

const optionWheelRoot = document.getElementById('option-wheel-root');
if (optionWheelRoot) {
  ReactDOM.createRoot(optionWheelRoot).render(
    <React.StrictMode>
      <OptionWheelDemo />
    </React.StrictMode>,
  )
}
