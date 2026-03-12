'use client';

import React from 'react';

interface HealthFactorBarProps {
  value: number; // e.g. 1.5
}

export const HealthFactorBar = ({ value }: HealthFactorBarProps) => {
  // Normalize value for the bar (clamp between 0 and 3 for visual)
  const normalized = Math.min(Math.max(value, 0), 3);
  const percentage = (normalized / 3) * 100;

  const getColor = () => {
    if (value < 1.1) return 'bg-red-500 shadow-red-500/50';
    if (value < 1.5) return 'bg-yellow-500 shadow-yellow-500/50';
    return 'bg-cyan-500 shadow-cyan-500/50';
  };

  return (
    <div className="w-full space-y-2">
      <div className="flex justify-between items-end">
        <span className="text-xs font-bold text-white/50 uppercase tracking-widest">Health Factor</span>
        <span className={`text-xl font-black ${value < 1.1 ? 'text-red-400' : value < 1.5 ? 'text-yellow-400' : 'text-cyan-400'}`}>
          {value > 100 ? '∞' : value.toFixed(2)}
        </span>
      </div>
      <div className="h-2 w-full bg-white/5 rounded-full overflow-hidden border border-white/5">
        <div 
          className={`h-full transition-all duration-1000 ease-out shadow-[0_0_10px_rgba(0,0,0,0.5)] ${getColor()}`}
          style={{ width: `${percentage}%` }}
        />
      </div>
      <div className="flex justify-between text-[10px] text-white/30 font-medium">
        <span>0.0</span>
        <span>1.5</span>
        <span>3.0+</span>
      </div>
    </div>
  );
};
