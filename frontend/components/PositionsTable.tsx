import React from 'react';
import { formatUnits } from 'viem';

interface AssetData {
  symbol: string;
  address: `0x${string}`;
  decimals: number;
  aTokenAddress?: `0x${string}`;
  debtTokenAddress?: `0x${string}`;
  walletBalance: bigint;
  aTokenBalance: bigint;
  debtBalance: bigint;
}

interface PositionsTableProps {
  assets: AssetData[];
}

export const PositionsTable: React.FC<PositionsTableProps> = ({ assets }) => {
  const suppliedAssets = assets.filter((a) => a.aTokenBalance > 0n);
  const borrowedAssets = assets.filter((a) => a.debtBalance > 0n);

  return (
    <div className="space-y-6">
      <div className="bg-[var(--color-bg-card)] rounded-xl border border-[var(--color-border)] overflow-hidden">
        <div className="p-5 border-b border-[var(--color-border)] bg-[var(--color-bg-elevated)]/50">
          <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">Your Supplied Assets</h2>
        </div>
        
        {suppliedAssets.length === 0 ? (
          <div className="p-8 text-center text-[var(--color-text-secondary)] text-sm">
            You have not supplied any assets yet.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm text-left">
              <thead className="text-xs text-[var(--color-text-secondary)] uppercase bg-[var(--color-bg-primary)]/50">
                <tr>
                  <th className="px-6 py-4 font-medium">Asset</th>
                  <th className="px-6 py-4 font-medium text-right">Balance</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--color-border)]">
                {suppliedAssets.map((asset) => (
                  <tr key={asset.symbol} className="bg-[var(--color-bg-card)] hover:bg-[var(--color-bg-elevated)] transition-colors">
                    <td className="px-6 py-4 font-medium flex items-center gap-2">
                      <div className="w-8 h-8 rounded-full bg-[var(--color-bg-primary)] border border-[var(--color-border)] flex items-center justify-center font-bold text-xs">
                        {asset.symbol[0]}
                      </div>
                      {asset.symbol}
                    </td>
                    <td className="px-6 py-4 text-right">
                      {Number(formatUnits(asset.aTokenBalance, asset.decimals)).toFixed(4)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="bg-[var(--color-bg-card)] rounded-xl border border-[var(--color-border)] overflow-hidden">
        <div className="p-5 border-b border-[var(--color-border)] bg-[var(--color-bg-elevated)]/50">
          <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">Your Borrowed Assets</h2>
        </div>
        
        {borrowedAssets.length === 0 ? (
          <div className="p-8 text-center text-[var(--color-text-secondary)] text-sm">
            You have not borrowed any assets yet.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm text-left">
              <thead className="text-xs text-[var(--color-text-secondary)] uppercase bg-[var(--color-bg-primary)]/50">
                <tr>
                  <th className="px-6 py-4 font-medium">Asset</th>
                  <th className="px-6 py-4 font-medium text-right">Debt</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--color-border)]">
                {borrowedAssets.map((asset) => (
                  <tr key={asset.symbol} className="bg-[var(--color-bg-card)] hover:bg-[var(--color-bg-elevated)] transition-colors text-[var(--color-red)]">
                    <td className="px-6 py-4 font-medium flex items-center gap-2 text-[var(--color-text-primary)]">
                      <div className="w-8 h-8 rounded-full bg-[var(--color-bg-primary)] border border-[var(--color-border)] flex items-center justify-center font-bold text-xs">
                        {asset.symbol[0]}
                      </div>
                      {asset.symbol}
                    </td>
                    <td className="px-6 py-4 text-right font-medium">
                      {Number(formatUnits(asset.debtBalance, asset.decimals)).toFixed(4)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};
