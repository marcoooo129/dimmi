import React, { useState, useEffect } from 'react';
import OptionWheel from './OptionWheel';

const SCENARIOS = [
  {
    label: 'Caffè',
    source: 'Vorrei un caffè, per favore.',
    result: 'I would like a coffee, please.',
    direction: 'Italiano <span>→</span> English',
    analysis: '<strong>per favore</strong><br>Please (used for polite requests)'
  },
  {
    label: 'Viaggio',
    source: "Dov'è la stazione ferroviaria?",
    result: 'Where is the train station?',
    direction: 'Italiano <span>→</span> English',
    analysis: "<strong>Dov'è</strong><br>Where is (contraction of dove + è)"
  },
  {
    label: 'Lavoro',
    source: 'Possiamo fissare una riunione?',
    result: 'Can we schedule a meeting?',
    direction: 'Italiano <span>→</span> English',
    analysis: '<strong>fissare</strong><br>To schedule/fix'
  },
  {
    label: 'Slang',
    source: 'Che figata!',
    result: 'How cool!',
    direction: 'Italiano <span>→</span> English',
    analysis: '<strong>figata</strong><br>Cool thing (slang)'
  },
  {
    label: 'Arte',
    source: 'Questo quadro è un capolavoro.',
    result: 'This painting is a masterpiece.',
    direction: 'Italiano <span>→</span> English',
    analysis: '<strong>capolavoro</strong><br>Masterpiece'
  }
];

export default function OptionWheelDemo() {
  const [items] = useState(SCENARIOS.map(s => s.label));

  const handleChange = (index, item) => {
    const scenario = SCENARIOS[index];
    if (!scenario) return;

    // Update the DOM elements in vanilla HTML
    const domSource = document.getElementById('demo-source');
    const domResult = document.getElementById('demo-result');
    const domAnalysis = document.getElementById('demo-analysis');
    const domDirection = document.getElementById('demo-direction');

    if (domSource) domSource.innerHTML = scenario.source;
    if (domResult) domResult.innerHTML = scenario.result;
    if (domAnalysis) domAnalysis.innerHTML = scenario.analysis;
    if (domDirection) domDirection.innerHTML = scenario.direction;
  };

  useEffect(() => {
    // Initial call to set the default state
    handleChange(0, SCENARIOS[0].label);
  }, []);

  return (
    <div style={{ width: '100%', height: '100%' }}>
      <OptionWheel
        items={items}
        defaultSelected={0}
        textColor="rgba(255, 250, 242, 0.4)"
        activeColor="#fffaf2"
        side="left"
        fontSize={2}
        spacing={1.8}
        curve={1.2}
        tilt={15}
        blur={1.5}
        fade={0.3}
        smoothing={150}
        inset={30}
        loop={false}
        draggable={true}
        onChange={handleChange}
      />
    </div>
  );
}
