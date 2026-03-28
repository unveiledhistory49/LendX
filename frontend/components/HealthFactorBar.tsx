import React from "react";
import { formatUnits } from "viem";
import { AlertCircle } from "lucide-react";
import { cn } from "./UI/TxButton";

interface HealthFactorBarProps {
  healthFactorRaw?: bigint;
  projectedHealthFactorRaw?: bigint;
}

export const HealthFactorBar: React.FC<HealthFactorBarProps> = ({ healthFactorRaw, projectedHealthFactorRaw }) => {
  const formatHF = (val: bigint | undefined) => {
    if (val === undefined || val === 0n || val === BigInt(2**256 - 1)) return null; // Uninitialized or max indicates no borrow
    return Number(formatUnits(val, 18));
  };

  const hf = formatHF(healthFactorRaw);
  const projHf = formatHF(projectedHealthFactorRaw);
  const displayHf = projHf !== null ? projHf : hf;

  if (hf === null && projHf === null) {
    return (
      <div className="w-full bg-[var(--color-bg-card)] rounded-xl p-4 border border-[var(--color-border)] opacity-50">
        <div className="flex justify-between items-center mb-2">
          <span className="text-sm text-[var(--color-text-secondary)] font-medium uppercase tracking-wider">Health Factor</span>
          <span className="text-lg font-bold">--</span>
        </div>
        <div className="h-2 bg-[var(--color-bg-elevated)] rounded-full overflow-hidden" />
      </div>
    );
  }

  // Cap display at 3 for the bar progress
  const clampedHf = Math.min(Math.max(displayHf || 0, 0), 3);
  const percent = (clampedHf / 3) * 100;

  let stateColor = "bg-[var(--color-green)] text-[var(--color-green)]";
  let barColorClass = "bg-[var(--color-green)]";
  
  if (displayHf !== null && displayHf < 1.0) {
    stateColor = "text-[var(--color-red)]";
    barColorClass = "bg-[var(--color-red)]";
  } else if (displayHf !== null && displayHf < 1.5) {
    stateColor = "text-[var(--color-yellow)]";
    barColorClass = "bg-[var(--color-yellow)]";
  }

  const isLiquidatable = displayHf !== null && displayHf < 1.0;

  return (
    <div className={cn("w-full rounded-xl p-4 border transition-all", isLiquidatable ? "bg-[var(--color-red)]/10 border-[var(--color-red)]/30 scale-[1.02]" : "bg-[var(--color-bg-card)] border-[var(--color-border)]")}>
      <div className="flex justify-between items-end mb-3">
        <div>
          <h3 className="text-sm text-[var(--color-text-secondary)] font-medium uppercase tracking-wider mb-1">Health Factor</h3>
          <div className="flex items-center gap-3">
            <span className={cn("text-2xl font-bold tracking-tight", stateColor)}>
              {displayHf?.toFixed(2)}{projHf !== null ? "*" : ""}
            </span>
            {isLiquidatable && (
              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded text-xs font-semibold bg-[var(--color-red)] text-white animate-pulse shadow-[0_0_15px_rgba(239,68,68,0.5)]">
                <AlertCircle className="w-3.5 h-3.5" /> LIQUIDATABLE
              </span>
            )}
          </div>
        </div>
      </div>
      
      <div className="h-3 w-full bg-[var(--color-bg-elevated)] rounded-full overflow-hidden ring-1 ring-inset ring-white/5 relative">
        <div 
          className={cn("h-full transition-all duration-500 ease-out", barColorClass)}
          style={{ width: `${percent}%` }}
        />
        {/* Markers */}
        <div className="absolute top-0 bottom-0 left-1/3 w-[2px] bg-red-500/50 z-10" title="Liquidation Threshold" />
      </div>
      <div className="flex justify-between text-xs text-[var(--color-text-secondary)] mt-2 font-medium">
        <span>0.0</span>
        <span className="text-red-400">1.0</span>
        <span>1.5</span>
        <span>3.0+</span>
      </div>
    </div>
  );
};
