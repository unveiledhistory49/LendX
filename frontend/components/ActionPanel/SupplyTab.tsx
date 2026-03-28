import React, { useState, useEffect } from "react";
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { LENDING_POOL_ABI, ERC20_ABI } from "../../lib/abis";
import { TxButton, TransactionState } from "../UI/TxButton";
import { useToast } from "../UI/ToastProvider";

export const SupplyTab = ({ assets, poolAddress, refetchAll }: any) => {
  const { address } = useAccount();
  const { addToast } = useToast();
  
  const [selectedAssetIdx, setSelectedAssetIdx] = useState(0);
  const [amount, setAmount] = useState("");
  
  const selectedAsset = assets[selectedAssetIdx];
  
  // Smart Contract Hooks
  const { writeContractAsync: approveAsync, data: approveTxHash, isPending: isApproveWaiting } = useWriteContract();
  const { writeContractAsync: supplyAsync, data: supplyTxHash, isPending: isSupplyWaiting } = useWriteContract();

  const { isLoading: isApprovePending, isSuccess: isApproveSuccess } = useWaitForTransactionReceipt({ hash: approveTxHash });
  const { isLoading: isSupplyPending, isSuccess: isSupplySuccess } = useWaitForTransactionReceipt({ hash: supplyTxHash });

  // Reset amount on success
  useEffect(() => {
    if (isSupplySuccess) {
      addToast({ type: "success", title: `Supplied ${selectedAsset?.symbol}`, txHash: supplyTxHash });
      setAmount("");
      refetchAll();
    }
  }, [isSupplySuccess]);

  const handleMax = () => {
    if (!selectedAsset) return;
    setAmount(formatUnits(selectedAsset.walletBalance, selectedAsset.decimals));
  };

  const amountBigInt = amount ? parseUnits(amount, selectedAsset?.decimals || 18) : 0n;
  const isZero = amountBigInt === 0n;
  const exceedsBalance = selectedAsset && amountBigInt > selectedAsset.walletBalance;

  // Derive Approve State
  let approveState: TransactionState = "idle";
  if (isApproveWaiting) approveState = "waiting";
  else if (isApprovePending) approveState = "pending";
  else if (isApproveSuccess) approveState = "success";

  // Derive Supply State
  let supplyState: TransactionState = "idle";
  if (isSupplyWaiting) supplyState = "waiting";
  else if (isSupplyPending) supplyState = "pending";
  else if (isSupplySuccess) supplyState = "success";

  const handleApprove = async () => {
    try {
      if (!selectedAsset) return;
      await approveAsync({
        address: selectedAsset.address,
        abi: ERC20_ABI,
        functionName: "approve",
        args: [poolAddress, amountBigInt],
      });
    } catch (err: any) {
      addToast({ type: "error", title: "Approval Failed", message: err.shortMessage || err.message });
    }
  };

  const handleSupply = async () => {
    try {
      if (!selectedAsset || !address) return;
      await supplyAsync({
        address: poolAddress,
        abi: LENDING_POOL_ABI,
        functionName: "supply",
        args: [selectedAsset.address, amountBigInt, address],
      });
    } catch (err: any) {
      addToast({ type: "error", title: "Supply Failed", message: err.shortMessage || err.message });
    }
  };

  // Only show supply button if we have success fully approved (or are waiting/pending for supply itself).
  // Ideally we should read allowance, but for simplicity we rely on the flow: user clicks approve, then user clicks supply
  const showSupplyBtn = isApproveSuccess || supplyState === "waiting" || supplyState === "pending" || supplyState === "success";

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-2">
        <label className="text-sm text-[var(--color-text-secondary)] font-medium">Select Asset</label>
        <select 
          className="w-full bg-[var(--color-bg-elevated)] border border-[var(--color-border)] rounded-lg px-4 py-3 outline-none focus:ring-2 focus:ring-[var(--color-accent)] transition-all app-appearance-none cursor-pointer"
          value={selectedAssetIdx}
          onChange={(e) => {
            setSelectedAssetIdx(Number(e.target.value));
            setAmount("");
          }}
        >
          {assets.map((a: any, i: number) => (
            <option key={a.symbol} value={i}>{a.symbol}</option>
          ))}
        </select>
      </div>

      <div className="flex flex-col gap-2">
        <div className="flex justify-between items-end">
          <label className="text-sm text-[var(--color-text-secondary)] font-medium">Amount to Supply</label>
          <span className="text-xs text-[var(--color-text-secondary)]">
            Wallet: {selectedAsset ? formatUnits(selectedAsset.walletBalance, selectedAsset.decimals) : "0"} {selectedAsset?.symbol}
          </span>
        </div>
        <div className="relative">
          <input
            type="number"
            placeholder="0.00"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="w-full bg-[var(--color-bg-elevated)] border border-[var(--color-border)] rounded-lg pl-4 pr-16 py-3 outline-none focus:ring-2 focus:ring-[var(--color-accent)] transition-all font-mono text-lg"
          />
          <button
            onClick={handleMax}
            className="absolute right-2 top-1/2 -translate-y-1/2 text-xs font-bold text-[var(--color-accent)] hover:bg-[var(--color-accent)]/10 px-2 py-1 rounded transition-colors"
          >
            MAX
          </button>
        </div>
        {exceedsBalance && <span className="text-xs text-[var(--color-red)] mt-1">Amount exceeds exact wallet balance</span>}
      </div>

      <div className="mt-4 flex flex-col gap-3">
        {!showSupplyBtn ? (
          <TxButton
            idleText={`Approve ${selectedAsset?.symbol}`}
            txState={approveState}
            txHash={approveTxHash}
            onConfirm={handleApprove}
            disabled={isZero || exceedsBalance || !address}
          />
        ) : (
          <TxButton
            idleText="Supply"
            txState={supplyState}
            txHash={supplyTxHash}
            onConfirm={handleSupply}
            disabled={isZero || exceedsBalance}
          />
        )}
      </div>
    </div>
  );
};
