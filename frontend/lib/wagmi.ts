import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http } from 'wagmi';
import { SUPPORTED_CHAINS } from './constants';
import { sepolia, baseSepolia } from 'viem/chains';

const anvil = SUPPORTED_CHAINS[0];

export const config = getDefaultConfig({
  appName: 'LendX Protocol',
  projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID || 'df8573210777e408ec210081d4576324', // Fallback or provided ID
  chains: [anvil, sepolia, baseSepolia],
  transports: {
    [anvil.id]: http(),
    [sepolia.id]: http(process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL || 'https://go.getblock.io/4d71ff368a664d2ebccf9e359d8c7de6'),
    [baseSepolia.id]: http(process.env.NEXT_PUBLIC_BASE_SEPOLIA_RPC_URL || 'https://go.getblock.io/2f70d59587494874b59fb4a56a514fdd'),
  },
  ssr: false,
});
