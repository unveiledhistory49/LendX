import { sepolia, baseSepolia } from 'viem/chains';
import type { Chain } from 'viem';

type AddressLike = `0x${string}`;

interface ChainAddresses {
  link: AddressLike;
  oracle: AddressLike;
  pool: AddressLike;
  strategy: AddressLike;
  usdc: AddressLike;
  wbtc: AddressLike;
  weth: AddressLike;
}

export const ADDRESSES: Record<number, ChainAddresses> = {
  31337: {
    link: "0x0165878A594ca255338adfa4d48449f69242Eb8F",
    oracle: "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318",
    pool: "0x9A676e781A523b5d0C0e43731313A708CB607508",
    strategy: "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
    usdc: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
    wbtc: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
    weth: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  },
  11155111: {
    link: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
    oracle: "0x00472C0dA2a058D52cB577dC009890050D1F401B",
    pool: "0xCCe7623c811d97f4bef16C99e95419Cb0C96FB30",
    strategy: "0xdD9Dc16177734f0CA0ac94AC7414377f7Ea37BCd",
    usdc: "0x1C7d4B196CB0232B3044439008c7c10C1F618E4D",
    wbtc: "0x92F3B0865d2730Bc56188319daEF22A842f2104f",
    weth: "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9",
  },
  84532: {
    link: "0x95f6e7eFc78e3d8d2dE1dfDCD5cD0Ac9ae69E0e9",
    oracle: "0xBbD100a3e9E3aC2d070C1beC6EA19caE06C714ff",
    pool: "0xEfe0201a041636E4A9bD1AE3e5cD56985b3A9196",
    strategy: "0xBE3f42aa0Ac12C2B7E6a91a0dD5EeFde39581476",
    usdc: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
    wbtc: "0xE16c6C68D6EBd3394acD48ddcA118Fe5ebFFEf1c",
    weth: "0x4200000000000000000000000000000000000006",
  }
} as const;

const anvil: Chain = {
  id: 31337,
  name: "Anvil Localhouse",
  nativeCurrency: {
    decimals: 18,
    name: "Ether",
    symbol: "ETH",
  },
  rpcUrls: {
    default: { http: ["http://127.0.0.1:8545"] },
    public: { http: ["http://127.0.0.1:8545"] },
  },
};

export const SUPPORTED_CHAINS: Chain[] = [
  anvil,
  sepolia,
  baseSepolia
];

export const getAddresses = (chainId: number = 11155111) => {
  return ADDRESSES[chainId] || ADDRESSES[11155111];
};
