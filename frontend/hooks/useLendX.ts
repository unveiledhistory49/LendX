import { useReadContract, useReadContracts, useAccount, useChainId } from "wagmi";
import { LENDING_POOL_ABI, ATOKEN_ABI, DEBT_TOKEN_ABI, ERC20_ABI } from "../lib/abis";
import { getAddresses } from "../lib/constants";

export function useLendX() {
  const { address } = useAccount();
  const chainId = useChainId();
  const addresses = getAddresses(chainId);
  const poolAddress = addresses.pool as `0x${string}`;

  // 1. Fetch User Account Data
  const { data: userAccountData, refetch: refetchUserAccountData } = useReadContract({
    address: poolAddress,
    abi: LENDING_POOL_ABI,
    functionName: "getUserAccountData",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });

  // 2. We define the supported reserve assets from our constants
  const reserveAssets = [
    { symbol: "WETH", address: addresses.weth as `0x${string}`, decimals: 18 },
    { symbol: "USDC", address: addresses.usdc as `0x${string}`, decimals: 6 },
    { symbol: "WBTC", address: addresses.wbtc as `0x${string}`, decimals: 8 },
    { symbol: "LINK", address: addresses.link as `0x${string}`, decimals: 18 },
  ] as const;

  // 3. To fetch balances dynamically, we need aToken / debtToken addresses for each asset.
  // We can fetch ReserveData for all 4 assets
  const reserveDataCalls = reserveAssets.map((asset) => ({
    address: poolAddress,
    abi: LENDING_POOL_ABI,
    functionName: "getReserveData",
    args: [asset.address],
  }));

  const { data: reservesDataRaw } = useReadContracts({
    contracts: reserveDataCalls as any,
  });

  // Parse the aToken and debtToken addresses from reserveData
  const parsedReserves = reserveAssets.map((asset, i) => {
    const raw = reservesDataRaw?.[i]?.result as any;
    return {
      ...asset,
      aTokenAddress: raw?.[6] as `0x${string}` | undefined,
      debtTokenAddress: raw?.[7] as `0x${string}` | undefined,
    };
  });

  // 4. Batch fetch Wallet Balance, aToken Balance, and debtToken Balance for each asset
  const balanceCalls = parsedReserves.flatMap((reserve) => {
    if (!address) return [];
    const calls: any[] = [
      { address: reserve.address, abi: ERC20_ABI, functionName: "balanceOf", args: [address] },
    ];
    if (reserve.aTokenAddress) {
      calls.push({ address: reserve.aTokenAddress, abi: ATOKEN_ABI, functionName: "balanceOf", args: [address] });
    }
    if (reserve.debtTokenAddress) {
      calls.push({ address: reserve.debtTokenAddress, abi: DEBT_TOKEN_ABI, functionName: "balanceOf", args: [address] });
    }
    return calls;
  });

  const { data: balancesRaw, refetch: refetchBalances } = useReadContracts({
    contracts: balanceCalls as any,
    query: {
      enabled: !!address && balanceCalls.length > 0,
    },
  });

  // Re-map the flat balance responses back to the assets
  const assetsWithBalances = parsedReserves.map((reserve, i) => {
    if (!address || !balancesRaw) {
      return { ...reserve, walletBalance: 0n, aTokenBalance: 0n, debtBalance: 0n };
    }
    // Each asset pushed up to 3 calls if addresses exist natively.
    // To safely map back, we calculate offsets based on addresses present.
    let offset = 0;
    for (let j = 0; j < i; j++) {
      offset += 1;
      if (parsedReserves[j].aTokenAddress) offset += 1;
      if (parsedReserves[j].debtTokenAddress) offset += 1;
    }

    const walletBalance = (balancesRaw[offset]?.result as bigint) || 0n;
    const aTokenBalance = reserve.aTokenAddress ? ((balancesRaw[offset + 1]?.result as bigint) || 0n) : 0n;
    const debtBalance = reserve.debtTokenAddress ? ((balancesRaw[offset + 2]?.result as bigint) || 0n) : 0n;

    return {
      ...reserve,
      walletBalance,
      aTokenBalance,
      debtBalance,
    };
  });

  const refetchAll = async () => {
    await Promise.all([refetchUserAccountData(), refetchBalances()]);
  };

  return {
    poolAddress,
    userAccountData: userAccountData as readonly [bigint, bigint, bigint, bigint, bigint, bigint] | undefined,
    assets: assetsWithBalances,
    refetchAll,
  };
}
