import { WagmiProvider, useAccount, useReadContract, useChainId } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { RainbowKitProvider, darkTheme } from '@rainbow-me/rainbowkit';
import { config } from './wagmi';
import { Header } from '@/components/Header';
import { HealthFactor } from '@/components/HealthFactor';
import { ActionPanels } from '@/components/ActionPanels';
import { LENDING_POOL_ABI } from '@/lib/abis';
import { ADDRESSES } from '@/lib/constants';
import '@rainbow-me/rainbowkit/styles.css';

const queryClient = new QueryClient();

function AppContent() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const addresses = ADDRESSES[chainId as keyof typeof ADDRESSES] || ADDRESSES[11155111];

  const { data: accountData } = useReadContract({
    address: addresses.pool,
    abi: LENDING_POOL_ABI,
    functionName: 'getUserAccountData',
    args: address ? [address] : undefined,
    query: {
        enabled: !!address,
        refetchInterval: 5000
    }
  });

  // accountData returns:
  // [totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor]
  // We want the 6th element (index 5)
  const healthFactor = accountData ? (accountData as any)[5] as bigint : undefined;

  return (
    <div className="min-h-screen bg-[#050505] text-gray-200 font-sans selection:bg-blue-500/30">
      <Header />
      
      <main className="container mx-auto px-4 py-12 max-w-4xl animate-in fade-in duration-700">
        {!isConnected ? (
          <div className="flex flex-col items-center justify-center min-h-[50vh] text-center space-y-6">
            <div className="p-4 bg-gray-900/50 rounded-2xl border border-gray-800 backdrop-blur-sm">
               <h2 className="text-2xl font-bold text-white mb-2">Connect Your Wallet</h2>
               <p className="text-gray-400 max-w-sm">Welcome to LendX. Connect your wallet to supply assets, borrow against collateral, or manage your positions.</p>
            </div>
            <div className="animate-bounce">
              <span className="text-blue-500">Connect below ↓</span>
            </div>
          </div>
        ) : (
          <>
            <HealthFactor value={healthFactor} />
            <ActionPanels />
          </>
        )}
      </main>

      <footer className="mt-24 py-12 text-center text-gray-600 text-xs border-t border-gray-900 bg-gray-950/50">
        <div className="flex justify-center items-center gap-4 mb-4">
          <span className="w-1.5 h-1.5 rounded-full bg-blue-500"></span>
          <span className="uppercase tracking-[0.2em]">LendX Protocol Mainnet Beta</span>
          <span className="w-1.5 h-1.5 rounded-full bg-blue-500"></span>
        </div>
        <p>© 2026 LendX Decentralized Lending. Use with caution. Built by Gemini Agent.</p>
      </footer>
    </div>
  );
}

export default function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider theme={darkTheme({
          accentColor: '#3b82f6',
          borderRadius: 'medium',
        })}>
          <AppContent />
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}