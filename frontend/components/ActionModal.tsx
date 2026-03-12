'use client';

import React, { useState } from 'react';
import { Modal } from './Modal';
import { useWriteContract, useAccount, useBalance, useChainId } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { getAddresses } from '@/lib/constants';
import { LENDING_POOL_ABI } from '@/lib/abis';
import { AlertCircle, CheckCircle2, Loader2, Info } from 'lucide-react';

export type ActionType = 'Supply' | 'Borrow' | 'Repay' | 'Withdraw';

interface ActionModalProps {
  isOpen: boolean;
  onClose: () => void;
  type: ActionType;
  asset: {
    symbol: string;
    name: string;
    address: string;
    decimals: number;
  };
}

export const ActionModal = ({ isOpen, onClose, type, asset }: ActionModalProps) => {
  const [amount, setAmount] = useState('');
  const { address } = useAccount();
  const chainId = useChainId();
  const ADDRESSES = getAddresses(chainId);
  
  const { data: balanceData } = useBalance({
    address,
    token: asset.address as `0x${string}`,
  });

  const { writeContract, isPending, isSuccess, error, data: hash } = useWriteContract();

  const handleAction = async () => {
    if (!amount || isNaN(Number(amount))) return;
    
    const parsedAmount = parseUnits(amount, asset.decimals);

    if (type === 'Supply') {
      // Note: In a real app, check allowance first. 
      // For this high-fidelity demo, we assume allowance or trigger it.
      writeContract({
        address: ADDRESSES.pool as `0x${string}`,
        abi: LENDING_POOL_ABI,
        functionName: 'supply',
        args: [asset.address as `0x${string}`, parsedAmount, address as `0x${string}`],
      });
    } else if (type === 'Borrow') {
      writeContract({
        address: ADDRESSES.pool as `0x${string}`,
        abi: LENDING_POOL_ABI,
        functionName: 'borrow',
        args: [asset.address as `0x${string}`, parsedAmount],
      });
    } else if (type === 'Repay') {
      writeContract({
        address: ADDRESSES.pool as `0x${string}`,
        abi: LENDING_POOL_ABI,
        functionName: 'repay',
        args: [asset.address as `0x${string}`, parsedAmount],
      });
    } else if (type === 'Withdraw') {
      writeContract({
        address: ADDRESSES.pool as `0x${string}`,
        abi: LENDING_POOL_ABI,
        functionName: 'withdraw',
        args: [asset.address as `0x${string}`, parsedAmount, address as `0x${string}`],
      });
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={`${type} ${asset.symbol}`}>
      <div className="space-y-6">
        {/* Balance Info */}
        <div className="flex justify-between items-center text-sm">
          <span className="text-white/40">Available Balance</span>
          <span className="text-white font-medium">
            {balanceData ? `${parseFloat(formatUnits(balanceData.value, asset.decimals)).toFixed(4)} ${asset.symbol}` : '0.00'}
          </span>
        </div>

        {/* Amount Input */}
        <div className="relative group">
          <input
            type="text"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
            className="w-full h-16 bg-white/5 border border-white/10 rounded-2xl px-6 text-2xl font-bold text-white focus:outline-none focus:border-cyan-500/50 transition-all placeholder:text-white/10"
          />
          <button 
            onClick={() => setAmount(balanceData ? formatUnits(balanceData.value, asset.decimals) : '0')}
            className="absolute right-4 top-1/2 -translate-y-1/2 px-3 py-1 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 text-[10px] font-black uppercase tracking-widest rounded-lg transition-colors"
          >
            Max
          </button>
        </div>

        {/* Transaction Status */}
        {isPending && (
          <div className="flex items-center gap-3 p-4 bg-cyan-500/5 border border-cyan-500/20 rounded-xl text-cyan-400">
            <Loader2 className="animate-spin" size={18} />
            <span className="text-sm font-medium">Confirming transaction...</span>
          </div>
        )}

        {isSuccess && (
          <div className="flex items-center gap-3 p-4 bg-emerald-500/5 border border-emerald-500/20 rounded-xl text-emerald-400">
            <CheckCircle2 size={18} />
            <div className="flex flex-col">
              <span className="text-sm font-bold">Transaction Successful!</span>
              <a 
                href={`https://etherscan.io/tx/${hash}`} 
                target="_blank" 
                className="text-[10px] underline opacity-70 hover:opacity-100"
              >
                View on Explorer
              </a>
            </div>
          </div>
        )}

        {error && (
          <div className="flex items-center gap-3 p-4 bg-rose-500/5 border border-rose-500/20 rounded-xl text-rose-400">
            <AlertCircle size={18} />
            <span className="text-xs font-medium truncate">
              {error.message.includes('User rejected') ? 'Transaction rejected by user.' : 'Transaction failed.'}
            </span>
          </div>
        )}

        {/* Protocol Note */}
        <div className="flex gap-3 p-4 bg-white/5 rounded-xl text-white/40">
          <Info size={16} className="shrink-0" />
          <p className="text-[10px] leading-relaxed">
            Please ensure you have enough network fees (ETH) to cover the transaction. 
            All {type} operations are subject to real-time health factor validation.
          </p>
        </div>

        {/* Action Button */}
        <button
          onClick={handleAction}
          disabled={isPending || !amount || parseFloat(amount) <= 0}
          className={`w-full h-14 rounded-2xl font-black uppercase tracking-widest transition-all active:scale-[0.98] ${
            isPending || !amount || parseFloat(amount) <= 0
              ? 'bg-white/5 text-white/20 cursor-not-allowed'
              : 'bg-cyan-500 text-black hover:bg-cyan-400 shadow-lg shadow-cyan-500/20'
          }`}
        >
          {isPending ? 'Processing...' : `${type} ${asset.symbol}`}
        </button>
      </div>
    </Modal>
  );
};
