import { formatUnits } from 'viem';
import { clsx } from 'clsx';
import { AlertTriangle } from 'lucide-react';

interface HealthFactorProps {
  value: bigint | undefined;
}

export function HealthFactor({ value }: HealthFactorProps) {
  // Handle undefined (loading) or 0 (no debt)
  // If value is huge (MaxUint256), user has no debt -> infinite health
  const isInfinite = value && value > BigInt("1000000000000000000000000"); // > 1M is practically infinite here
  
  // Parse to number for UI logic (safe for 18 decimals unless massive)
  const numericValue = value ? Number(formatUnits(value, 18)) : 0;
  
  let status: 'safe' | 'warning' | 'danger' = 'safe';
  if (numericValue < 1.0 && value !== undefined) status = 'danger';
  else if (numericValue < 1.5 && value !== undefined) status = 'warning';

  // Calculate percentage for bar width (capped at 2.0 for visual scaling)
  const percentage = Math.min((numericValue / 2.0) * 100, 100);

  return (
    <div className="w-full max-w-2xl mx-auto mb-8 p-6 bg-gray-900 rounded-xl border border-gray-800 shadow-2xl">
      <div className="flex justify-between items-end mb-4">
        <h2 className="text-gray-400 font-medium uppercase tracking-wider text-sm">Account Health</h2>
        <div className="text-3xl font-mono font-bold text-white">
          {isInfinite ? '∞' : numericValue.toFixed(2)}
        </div>
      </div>

      <div className="relative h-6 bg-gray-800 rounded-full overflow-hidden mb-2">
        {/* Background markers for 1.0 and 1.5 */}
        <div className="absolute top-0 bottom-0 left-[50%] w-0.5 bg-gray-700 z-10" title="1.0 Liquidation"></div>
        <div className="absolute top-0 bottom-0 left-[75%] w-0.5 bg-gray-700 z-10" title="1.5 Safe"></div>

        <div 
          className={clsx(
            "h-full transition-all duration-500 ease-out",
            status === 'safe' && "bg-gradient-to-r from-green-600 to-emerald-400",
            status === 'warning' && "bg-gradient-to-r from-yellow-600 to-amber-400",
            status === 'danger' && "bg-gradient-to-r from-red-600 to-rose-500 animate-pulse"
          )}
          style={{ width: `${isInfinite ? 100 : percentage}%` }}
        />
      </div>

      <div className="flex justify-between text-xs text-gray-500 font-mono">
        <span>0.0</span>
        <span className="ml-[50%] transform -translate-x-1/2">1.0</span>
        <span className="ml-[25%] transform -translate-x-1/2">1.5</span>
        <span>2.0+</span>
      </div>

      {status === 'danger' && !isInfinite && (
        <div className="mt-4 flex items-center gap-3 p-3 bg-red-900/20 border border-red-800 rounded-lg text-red-200 animate-pulse">
          <AlertTriangle className="w-5 h-5 text-red-500" />
          <span className="font-bold">WARNING: POSITION LIQUIDATABLE</span>
        </div>
      )}
    </div>
  );
}
