import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia, baseSepolia } from 'wagmi/chains';
import { anvil } from './lib/constants';

export const config = getDefaultConfig({
  appName: 'LendX Protocol',
  projectId: 'YOUR_PROJECT_ID', // Replaced with a placeholder as I don't have one, but it works for dev
  chains: [anvil, sepolia, baseSepolia],
  ssr: false, // Vite is SPA
});
