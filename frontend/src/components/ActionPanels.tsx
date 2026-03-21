import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract, useChainId } from 'wagmi';
import { parseUnits } from 'viem';
import { LENDING_POOL_ABI, ERC20_ABI } from '@/lib/abis';
import { ADDRESSES } from '@/lib/constants';
import { Loader2, CheckCircle2, ArrowRightLeft } from 'lucide-react';
import { clsx } from 'clsx';

export function ActionPanels() {
  const [activeTab, setActiveTab] = useState<'supply' | 'borrow' | 'repay' | 'liquidate'>('supply');
  const [asset, setAsset] = useState('weth');
  const [amount, setAmount] = useState('');
  const [borrower, setBorrower] = useState('');

  const chainId = useChainId();
  const addresses = ADDRESSES[chainId as keyof typeof ADDRESSES] || ADDRESSES[11155111];

  return (
    <div className="w-full max-w-2xl mx-auto bg-gray-900 rounded-xl border border-gray-800 shadow-xl overflow-hidden mt-8">
      <div className="flex border-b border-gray-800">
        {['supply', 'borrow', 'repay', 'liquidate'].map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab as any)}
            className={clsx(
              "flex-1 py-4 text-sm font-medium uppercase tracking-wider transition-colors focus:outline-none",
              activeTab === tab 
                ? "bg-gray-800 text-white border-b-2 border-blue-500" 
                : "text-gray-500 hover:text-gray-300 hover:bg-gray-800/50"
            )}
          >
            {tab}
          </button>
        ))}
      </div>

      <div className="p-6">
        <PanelContent 
          type={activeTab} 
          asset={asset} 
          setAsset={setAsset} 
          amount={amount} 
          setAmount={setAmount}
          borrower={borrower}
          setBorrower={setBorrower}
          addresses={addresses}
        />
      </div>
    </div>
  );
}

interface PanelContentProps {
  type: 'supply' | 'borrow' | 'repay' | 'liquidate';
  asset: string;
  setAsset: (a: string) => void;
  amount: string;
  setAmount: (a: string) => void;
  borrower: string;
  setBorrower: (b: string) => void;
  addresses: any;
}

function PanelContent({ type, asset, setAsset, amount, setAmount, borrower, setBorrower, addresses }: PanelContentProps) {
  const { address } = useAccount();
  const { writeContract, isPending, data: hash, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // Reset state on tab change or success
  useEffect(() => {
    if (isSuccess) {
      const timer = setTimeout(() => reset(), 3000);
      return () => clearTimeout(timer);
    }
  }, [isSuccess, reset]);

  const assetAddress = asset === 'weth' ? addresses.weth : addresses.usdc;
  const decimals = 18; 

  // Read allowance
  const { data: allowance } = useReadContract({
    address: assetAddress,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: [address!, addresses.pool],
    query: { 
      enabled: !!address && (type === 'supply' || type === 'repay'),
      refetchInterval: 2000 
    }
  });

  const parsedAmount = amount ? parseUnits(amount, decimals) : 0n;
  const isApprovalNeeded = (allowance || 0n) < parsedAmount && (type === 'supply' || type === 'repay');

  const handleExecute = () => {
    if (!amount || !address) return;

    if (isApprovalNeeded) {
        writeContract({
            address: assetAddress,
            abi: ERC20_ABI,
            functionName: 'approve',
            args: [addresses.pool, parsedAmount]
        });
        return;
    }

    try {
      if (type === 'supply') {
        writeContract({
          address: addresses.pool,
          abi: LENDING_POOL_ABI,
          functionName: 'supply',
          args: [assetAddress, parsedAmount, address]
        });
      } else if (type === 'borrow') {
        writeContract({
          address: addresses.pool,
          abi: LENDING_POOL_ABI,
          functionName: 'borrow',
          args: [assetAddress, parsedAmount]
        });
      } else if (type === 'repay') {
        writeContract({
          address: addresses.pool,
          abi: LENDING_POOL_ABI,
          functionName: 'repay',
          args: [assetAddress, parsedAmount]
        });
      } else if (type === 'liquidate') {
        // For liquidate: collateral is the OTHER asset (simple assumption for MVP UI)
        const collateral = asset === 'weth' ? addresses.usdc : addresses.weth;
        writeContract({
            address: addresses.pool,
            abi: LENDING_POOL_ABI,
            functionName: 'liquidationCall',
            args: [collateral, assetAddress, borrower as `0x${string}`, parsedAmount, false]
        });
      }
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row gap-4">
        <div className="flex-1">
          <label className="block text-xs font-medium text-gray-500 mb-2 uppercase tracking-wide">
            {type === 'liquidate' ? 'Debt Asset to Cover' : 'Asset'}
          </label>
          <div className="relative">
            <select 
              value={asset}
              onChange={(e) => setAsset(e.target.value)}
              className="w-full appearance-none bg-gray-800 border border-gray-700 rounded-lg p-3 text-white focus:ring-2 focus:ring-blue-500 outline-none cursor-pointer"
            >
              <option value="weth">WETH</option>
              <option value="usdc">USDC</option>
            </select>
            <div className="absolute inset-y-0 right-0 flex items-center px-2 pointer-events-none text-gray-400">
              <ArrowRightLeft className="w-4 h-4 rotate-90" />
            </div>
          </div>
        </div>
       
        <div className="flex-[2]">
          <label className="block text-xs font-medium text-gray-500 mb-2 uppercase tracking-wide">Amount</label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
            className="w-full bg-gray-800 border border-gray-700 rounded-lg p-3 text-white focus:ring-2 focus:ring-blue-500 outline-none placeholder-gray-600 font-mono"
          />
        </div>
      </div>

      {type === 'liquidate' && (
        <div>
            <label className="block text-xs font-medium text-gray-500 mb-2 uppercase tracking-wide">Borrower Address</label>
            <input
                type="text"
                value={borrower}
                onChange={(e) => setBorrower(e.target.value)}
                placeholder="0x..."
                className="w-full bg-gray-800 border border-gray-700 rounded-lg p-3 text-white focus:ring-2 focus:ring-blue-500 outline-none placeholder-gray-600 font-mono text-sm"
            />
        </div>
      )}

      <button
        onClick={handleExecute}
        disabled={isPending || isConfirming || !amount || !address}
        className={clsx(
          "w-full py-4 rounded-lg font-bold text-lg uppercase tracking-wider transition-all transform active:scale-[0.99]",
          isPending || isConfirming || !amount || !address
            ? "bg-gray-800 cursor-not-allowed text-gray-500 border border-gray-700" 
            : "bg-gradient-to-r from-blue-600 to-blue-500 hover:from-blue-500 hover:to-blue-400 text-white shadow-lg shadow-blue-900/30 border border-blue-500/50"
        )}
      >
        {isPending || isConfirming ? (
            <span className="flex items-center justify-center gap-2">
                <Loader2 className="animate-spin w-5 h-5" /> 
                {isPending ? 'Confirm in Wallet...' : 'Confirming Transaction...'}
            </span>
        ) : (
            isApprovalNeeded ? `Approve ${asset.toUpperCase()}` : `${type} ${asset.toUpperCase()}`
        )}
      </button>

      {isSuccess && (
        <div className="flex items-center gap-3 text-green-400 bg-green-900/10 p-4 rounded-lg border border-green-900/50 animate-in fade-in slide-in-from-bottom-2">
            <CheckCircle2 className="w-5 h-5 shrink-0" />
            <div>
              <p className="text-sm font-bold">Transaction Confirmed</p>
              <p className="text-xs text-green-500/80 mt-0.5 break-all font-mono">{hash}</p>
            </div>
        </div>
      )}
      
      {/* Helper Text */}
      <div className="text-center">
        {!address && <p className="text-sm text-yellow-500/80">Connect wallet to interact</p>}
      </div>
    </div>
  );
}