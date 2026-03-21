import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useReadContract, useChainId } from 'wagmi';
import { formatUnits } from 'viem';
import { PRICE_ORACLE_ABI } from '@/lib/abis';
import { ADDRESSES } from '@/lib/constants';
import { Activity } from 'lucide-react';

export function Header() {
  const chainId = useChainId();
  const addresses = ADDRESSES[chainId as keyof typeof ADDRESSES] || ADDRESSES[11155111];

  const { data: ethPrice } = useReadContract({
    address: addresses.oracle,
    abi: PRICE_ORACLE_ABI,
    functionName: 'getAssetPrice',
    args: [addresses.weth],
    query: {
      refetchInterval: 30_000,
    }
  });

  const formattedPrice = ethPrice ? (Number(formatUnits(ethPrice, 18))).toFixed(2) : '...';

  return (
    <header className="flex justify-between items-center p-6 border-b border-gray-800 bg-gray-900/50 backdrop-blur-sm sticky top-0 z-10">
      <div className="flex items-center gap-2">
        <Activity className="w-6 h-6 text-blue-500" />
        <h1 className="text-xl font-bold tracking-tight text-white">LendX Protocol</h1>
      </div>
      
      <div className="flex items-center gap-6">
        <div className="hidden md:flex items-center gap-2 text-sm font-medium text-gray-400 bg-gray-800/50 px-3 py-1.5 rounded-full border border-gray-700">
          <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></span>
          ETH Price: <span className="text-white">${formattedPrice}</span>
        </div>
        <ConnectButton showBalance={false} />
      </div>
    </header>
  );
}
