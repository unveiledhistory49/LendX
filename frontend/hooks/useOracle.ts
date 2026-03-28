import { useReadContract } from "wagmi";
import { PRICE_ORACLE_ABI } from "../lib/abis";
import { getAddresses } from "../lib/constants";
import { useMemo } from "react";
import { formatUnits } from "viem";

export function useOracle(chainId: number | undefined, assetAddress: `0x${string}` | undefined) {
  const addresses = getAddresses(chainId);

  const { data: priceData, isError, isLoading, refetch } = useReadContract({
    address: addresses.oracle as `0x${string}`,
    abi: PRICE_ORACLE_ABI,
    functionName: "getAssetPrice",
    args: assetAddress ? [assetAddress] : undefined,
    query: {
      enabled: !!assetAddress && !!addresses.oracle,
      refetchInterval: 30000, 
    },
  });

  const priceParsed = useMemo(() => {
    if (priceData === undefined) return 0;
    return Number(formatUnits(priceData as bigint, 8));
  }, [priceData]);

  return {
    price: priceParsed,
    priceRaw: priceData,
    isError,
    isLoading,
    refetch,
  };
}
