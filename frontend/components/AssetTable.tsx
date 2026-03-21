import { ActionModal, ActionType } from './ActionModal';
import { getAddresses } from '@/lib/constants';
import { useChainId } from 'wagmi';
import { useState } from 'react';

interface Asset {
  symbol: string;
  name: string;
  address: string;
  decimals: number;
  price: string;
  supplyAPY: string;
  borrowAPY: string;
  balance: string;
}

export const AssetTable = () => {
  const chainId = useChainId();
  const ADDRESSES = getAddresses(chainId);

  const ASSETS: Asset[] = [
    { symbol: 'WETH', name: 'Wrapped Ether', address: ADDRESSES.weth, decimals: 18, price: '$2,450.00', supplyAPY: '3.2%', borrowAPY: '5.1%', balance: '0.00' },
    { symbol: 'WBTC', name: 'Wrapped Bitcoin', address: ADDRESSES.wbtc, decimals: 8, price: '$64,200.00', supplyAPY: '1.8%', borrowAPY: '4.2%', balance: '0.00' },
    { symbol: 'USDC', name: 'USD Coin', address: ADDRESSES.usdc, decimals: 6, price: '$1.00', supplyAPY: '4.5%', borrowAPY: '6.8%', balance: '0.00' },
    { symbol: 'LINK', name: 'Chainlink', address: ADDRESSES.link, decimals: 18, price: '$18.20', supplyAPY: '2.1%', borrowAPY: '4.5%', balance: '0.00' },
  ];
  const [modalAsset, setModalAsset] = useState<Asset | null>(null);
  const [modalType, setModalType] = useState<ActionType>('Supply');

  const openModal = (asset: Asset, type: ActionType) => {
    setModalAsset(asset);
    setModalType(type);
  };

  return (
    <div className="glass-card overflow-hidden">
      <div className="px-6 py-4 border-b border-zinc-800 flex justify-between items-center">
        <h3 className="text-lg font-bold">Market Assets</h3>
        <div className="flex gap-4 text-xs font-bold text-zinc-500 tracking-widest uppercase">
          <span>Global TVL: $1.2M</span>
        </div>
      </div>
      
      <div className="overflow-x-auto">
        <table className="w-full text-left">
          <thead>
            <tr className="text-[10px] font-bold text-zinc-500 uppercase tracking-[0.2em] border-b border-zinc-800">
              <th className="px-6 py-4">Asset</th>
              <th className="px-6 py-4">Price</th>
              <th className="px-6 py-4 text-emerald-400">Supply APY</th>
              <th className="px-6 py-4 text-purple-400">Borrow APY</th>
              <th className="px-6 py-4">Wallet</th>
              <th className="px-6 py-4 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-800">
            {ASSETS.map((asset) => (
              <tr key={asset.symbol} className="group hover:bg-zinc-900/40 transition-colors">
                <td className="px-6 py-4">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-full bg-zinc-900 border border-zinc-800 flex items-center justify-center font-black text-xs text-cyan-400">
                      {asset.symbol[0]}
                    </div>
                    <div>
                      <div className="font-bold text-white leading-tight">{asset.symbol}</div>
                      <div className="text-[10px] text-zinc-500">{asset.name}</div>
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4 font-medium">{asset.price}</td>
                <td className="px-6 py-4 font-bold text-emerald-400">{asset.supplyAPY}</td>
                <td className="px-6 py-4 font-bold text-purple-400">{asset.borrowAPY}</td>
                <td className="px-6 py-4 text-zinc-400 text-sm font-medium">
                  {asset.balance} {asset.symbol}
                </td>
                <td className="px-6 py-4">
                  <div className="flex justify-end gap-2">
                    <button 
                      onClick={() => openModal(asset, 'Supply')}
                      className="px-4 py-1.5 rounded-lg bg-zinc-900 hover:bg-cyan-500 hover:text-black text-xs font-black uppercase tracking-tighter transition-all active:scale-95"
                    >
                      Supply
                    </button>
                    <button 
                      onClick={() => openModal(asset, 'Borrow')}
                      className="px-4 py-1.5 rounded-lg border border-zinc-800 hover:border-purple-500 hover:text-purple-400 text-xs font-black uppercase tracking-tighter transition-all active:scale-95"
                    >
                      Borrow
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {modalAsset && (
        <ActionModal 
          isOpen={!!modalAsset} 
          onClose={() => setModalAsset(null)} 
          type={modalType} 
          asset={modalAsset} 
        />
      )}
    </div>
  );
};
