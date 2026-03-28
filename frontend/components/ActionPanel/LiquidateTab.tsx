import React, { useState, useEffect } from "react";
import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from "wagmi";
import { isAddress, parseUnits, formatUnits } from "viem";
import { LENDING_POOL_ABI, ERC20_ABI } from "../../lib/abis";
import { TxButton, TransactionState } from "../UI/TxButton";
import { useToast } from "../UI/ToastProvider";
import { AlertCircle, Search } from "lucide-react";

export const LiquidateTab = ({ assets, poolAddress, refetchAll }: any) => {
  const { address: currentAccount } = useAccount();
  const { addToast } = useToast();
  
  const [searchInput, setSearchInput] = useState("");
  const [targetAddress, setTargetAddress] = useState<`0x${string}` | undefined>(undefined);
  
  const [collateralAssetIdx, setCollateralAssetIdx] = useState(0);
  const [debtAssetIdx, setDebtAssetIdx] = useState(0); // usually USDC
  const [amount, setAmount] = useState("");
  
  const collateralAsset = assets[collateralAssetIdx];
  const debtAsset = assets[debtAssetIdx];

  const handleLookup = () => {
    if (isAddress(searchInput)) {
      setTargetAddress(searchInput as `0x${string}`);
    } else {
      addToast({ type: "error", title: "Invalid Address", message: "Please enter a valid Ethereum address." });
    }
  };

  const { data: targetAccountData, isLoading: isLookupLoading } = useReadContract({
    address: poolAddress,
    abi: LENDING_POOL_ABI,
    functionName: "getUserAccountData",
    args: targetAddress ? [targetAddress] : undefined,
    query: {
      enabled: !!targetAddress,
    },
  });

  const { writeContractAsync: approveAsync, data: approveTxHash, isPending: isApproveWaiting } = useWriteContract();
  const { writeContractAsync: liquidateAsync, data: liquidateTxHash, isPending: isLiquidateWaiting } = useWriteContract();

  const { isLoading: isApprovePending, isSuccess: isApproveSuccess } = useWaitForTransactionReceipt({ hash: approveTxHash });
  const { isLoading: isLiquidatePending, isSuccess: isLiquidateSuccess } = useWaitForTransactionReceipt({ hash: liquidateTxHash });

  useEffect(() => {
    if (isLiquidateSuccess) {
      addToast({ type: "success", title: "Liquidation Executed", txHash: liquidateTxHash });
      setAmount("");
      refetchAll();
    }
  }, [isLiquidateSuccess]);

  const targetHF = targetAccountData?.[5];
  const formatHF = targetHF ? Number(formatUnits(targetHF, 18)) : null;
  const isLiquidatable = formatHF !== null && formatHF < 1.0;
  
  // Bonus derived from mock thresholds based on spec:
  let bonus = "0%";
  if (isLiquidatable) {
    if (formatHF! > 0.95) bonus = "5% (HF > 0.95)";
    else if (formatHF! > 0.8) bonus = "8% (HF > 0.80)";
    else bonus = "12% (HF <= 0.80)";
  }

  const isSelf = targetAddress?.toLowerCase() === currentAccount?.toLowerCase();
  
  const amountBigInt = amount ? parseUnits(amount, debtAsset?.decimals || 18) : 0n;
  const isZero = amountBigInt === 0n;

  let approveState: TransactionState = "idle";
  if (isApproveWaiting) approveState = "waiting";
  else if (isApprovePending) approveState = "pending";
  else if (isApproveSuccess) approveState = "success";

  let liquidateState: TransactionState = "idle";
  if (isLiquidateWaiting) liquidateState = "waiting";
  else if (isLiquidatePending) liquidateState = "pending";
  else if (isLiquidateSuccess) liquidateState = "success";

  const handleApprove = async () => {
    try {
      if (!debtAsset) return;
      await approveAsync({
        address: debtAsset.address,
        abi: ERC20_ABI,
        functionName: "approve",
        args: [poolAddress, amountBigInt],
      });
    } catch (err: any) {
      addToast({ type: "error", title: "Approval Failed", message: err.shortMessage || err.message });
    }
  };

  const handleLiquidate = async () => {
    try {
      if (!collateralAsset || !debtAsset || !targetAddress) return;
      await liquidateAsync({
        address: poolAddress,
        abi: LENDING_POOL_ABI,
        functionName: "liquidationCall",
        args: [collateralAsset.address, debtAsset.address, targetAddress, amountBigInt, false],
      });
    } catch (err: any) {
      addToast({ type: "error", title: "Liquidation Failed", message: err.shortMessage || err.message });
    }
  };

  const showLiquidateBtn = isApproveSuccess || liquidateState === "waiting" || liquidateState === "pending" || liquidateState === "success";

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-2">
        <label className="text-sm text-[var(--color-text-secondary)] font-medium">Borrower Address</label>
        <div className="flex gap-2">
          <input
            type="text"
            placeholder="0x..."
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            className="flex-1 bg-[var(--color-bg-elevated)] border border-[var(--color-border)] rounded-lg px-4 py-3 outline-none focus:ring-2 focus:ring-[var(--color-accent)] transition-all font-mono text-sm"
          />
          <button 
            onClick={handleLookup}
            className="bg-[var(--color-bg-elevated)] border border-[var(--color-border)] hover:bg-[var(--color-bg-card)] px-4 rounded-lg flex items-center justify-center transition-colors"
          >
            {isLookupLoading ? <span className="animate-spin w-5 h-5 border-2 border-[var(--color-text-secondary)] border-t-transparent rounded-full" /> : <Search className="w-5 h-5 text-[var(--color-text-secondary)]" />}
          </button>
        </div>
      </div>

      {targetAddress && targetAccountData && (
        <div className={`rounded-xl p-4 border ${isLiquidatable ? 'bg-[var(--color-red)]/10 border-[var(--color-red)]/30' : 'bg-[var(--color-green)]/10 border-[var(--color-green)]/30'}`}>
          <div className="flex justify-between items-center mb-3">
            <span className="text-sm font-medium text-[var(--color-text-secondary)]">Position Status</span>
            {isLiquidatable ? (
              <span className="text-xs font-bold text-[var(--color-red)] bg-[var(--color-red)]/20 px-2.5 py-1 rounded">LIQUIDATABLE</span>
            ) : (
              <span className="text-xs font-bold text-[var(--color-green)] bg-[var(--color-green)]/20 px-2.5 py-1 rounded">HEALTHY</span>
            )}
          </div>
          <div className="space-y-1.5 text-sm">
            <div className="flex justify-between">
              <span className="text-[var(--color-text-secondary)]">Health Factor</span>
              <span className={`font-mono font-medium ${isLiquidatable ? 'text-[var(--color-red)]' : 'text-[var(--color-green)]'}`}>{formatHF?.toFixed(4)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-[var(--color-text-secondary)]">Total Collateral (Base)</span>
              <span className="font-mono">{(Number(targetAccountData[0]) / 1e8).toFixed(2)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-[var(--color-text-secondary)]">Total Debt (Base)</span>
              <span className="font-mono">{(Number(targetAccountData[1]) / 1e8).toFixed(2)}</span>
            </div>
          </div>
        </div>
      )}

      {targetAddress && !isLiquidatable && targetAccountData && (
        <div className="text-center text-sm text-[var(--color-green)] bg-[var(--color-green)]/10 rounded p-3">
          This position is healthy and cannot be liquidated.
        </div>
      )}

      {isSelf && (
        <div className="text-center text-sm text-[var(--color-yellow)] bg-[var(--color-yellow)]/10 rounded p-3">
          You cannot liquidate your own position.
        </div>
      )}

      <div className={`flex flex-col gap-4 ${(!isLiquidatable || isSelf) && targetAddress ? 'opacity-50 pointer-events-none' : ''}`}>
        <div className="grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-2">
            <label className="text-sm text-[var(--color-text-secondary)] font-medium text-xs">Collateral to Receive</label>
            <select 
              className="w-full bg-[var(--color-bg-elevated)] border border-[var(--color-border)] rounded-lg px-3 py-2.5 outline-none focus:ring-2 focus:ring-[var(--color-accent)] transition-all cursor-pointer text-sm"
              value={collateralAssetIdx}
              onChange={(e) => setCollateralAssetIdx(Number(e.target.value))}
            >
              {assets.map((a: any, i: number) => (
                <option key={a.symbol} value={i}>{a.symbol}</option>
              ))}
            </select>
          </div>
          <div className="flex flex-col gap-2">
            <label className="text-sm text-[var(--color-text-secondary)] font-medium text-xs">Debt to Cover</label>
            <select 
              className="w-full bg-[var(--color-bg-elevated)] border border-[var(--color-border)] rounded-lg px-3 py-2.5 outline-none focus:ring-2 focus:ring-[var(--color-accent)] transition-all cursor-pointer text-sm"
              value={debtAssetIdx}
              onChange={(e) => {
                setDebtAssetIdx(Number(e.target.value));
                setAmount("");
              }}
            >
              {assets.map((a: any, i: number) => (
                <option key={a.symbol} value={i}>{a.symbol}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="flex flex-col gap-2">
          <div className="flex justify-between items-end">
             <label className="text-sm text-[var(--color-text-secondary)] font-medium">Amount to Cover</label>
          </div>
          <div className="relative">
            <input
              type="number"
              placeholder="0.00"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="w-full bg-[var(--color-bg-elevated)] border border-[var(--color-border)] rounded-lg pl-4 pr-20 py-3 outline-none focus:ring-2 focus:ring-[var(--color-accent)] transition-all font-mono text-lg"
            />
            {/* Standard Aave V3 closes up to 50% with some caveats, here we just do a dummy fill since we don't know the exact debt balance easily off-chain without another read call for the specific debt token of that user */}
            <span className="absolute right-4 top-1/2 -translate-y-1/2 text-xs font-bold text-[var(--color-text-secondary)]">
              {debtAsset?.symbol}
            </span>
          </div>
        </div>

        {isLiquidatable && (
          <div className="flex justify-between items-center text-sm text-[var(--color-text-secondary)] bg-[var(--color-bg-elevated)] p-3 rounded border border-[var(--color-border)]">
            <span>Liquidation Bonus</span>
            <span className="font-bold text-[var(--color-green)]">{bonus}</span>
          </div>
        )}

        <div className="mt-2 flex flex-col gap-3">
          {!showLiquidateBtn ? (
            <TxButton
              idleText={`Approve ${debtAsset?.symbol}`}
              txState={approveState}
              txHash={approveTxHash}
              onConfirm={handleApprove}
              disabled={isZero || !isLiquidatable || isSelf}
            />
          ) : (
            <TxButton
              idleText="Execute Liquidation"
              txState={liquidateState}
              txHash={liquidateTxHash}
              onConfirm={handleLiquidate}
              disabled={isZero || !isLiquidatable || isSelf}
            />
          )}
        </div>
      </div>
    </div>
  );
};
