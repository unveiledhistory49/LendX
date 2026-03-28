import React, { useState, useEffect } from "react";
import { useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits, formatUnits, maxUint256 } from "viem";
import { LENDING_POOL_ABI, ERC20_ABI } from "../../lib/abis";
import { TxButton, TransactionState } from "../UI/TxButton";
import { useToast } from "../UI/ToastProvider";

export const RepayTab = ({ assets, poolAddress, refetchAll }: any) => {
  const { addToast } = useToast();
  
  const [selectedAssetIdx, setSelectedAssetIdx] = useState(0);
  const [amount, setAmount] = useState("");
  const [isMax, setIsMax] = useState(false);
  
  const selectedAsset = assets[selectedAssetIdx];
  // Calculate if they even have debt
  const hasDebt = selectedAsset?.debtBalance > 0n;

  const { writeContractAsync: approveAsync, data: approveTxHash, isPending: isApproveWaiting } = useWriteContract();
  const { writeContractAsync: repayAsync, data: repayTxHash, isPending: isRepayWaiting } = useWriteContract();

  const { isLoading: isApprovePending, isSuccess: isApproveSuccess } = useWaitForTransactionReceipt({ hash: approveTxHash });
  const { isLoading: isRepayPending, isSuccess: isRepaySuccess } = useWaitForTransactionReceipt({ hash: repayTxHash });

  useEffect(() => {
    if (isRepaySuccess) {
      addToast({ type: "success", title: `Repaid ${selectedAsset?.symbol}`, txHash: repayTxHash });
      setAmount("");
      setIsMax(false);
      refetchAll();
    }
  }, [isRepaySuccess]);

  const handleMax = () => {
    if (!selectedAsset) return;
    setAmount(formatUnits(selectedAsset.debtBalance, selectedAsset.decimals));
    setIsMax(true);
  };

  const amountBigInt = isMax ? maxUint256 : (amount ? parseUnits(amount, selectedAsset?.decimals || 18) : 0n);
  const isZero = amountBigInt === 0n;

  let approveState: TransactionState = "idle";
  if (isApproveWaiting) approveState = "waiting";
  else if (isApprovePending) approveState = "pending";
  else if (isApproveSuccess) approveState = "success";

  let repayState: TransactionState = "idle";
  if (isRepayWaiting) repayState = "waiting";
  else if (isRepayPending) repayState = "pending";
  else if (isRepaySuccess) repayState = "success";

  const handleApprove = async () => {
    try {
      if (!selectedAsset) return;
      await approveAsync({
        address: selectedAsset.address,
        abi: ERC20_ABI,
        functionName: "approve",
        args: [poolAddress, amountBigInt === maxUint256 ? maxUint256 : amountBigInt],
      });
    } catch (err: any) {
      addToast({ type: "error", title: "Approval Failed", message: err.shortMessage || err.message });
    }
  };

  const handleRepay = async () => {
    try {
      if (!selectedAsset) return;
      await repayAsync({
        address: poolAddress,
        abi: LENDING_POOL_ABI,
        functionName: "repay",
        args: [selectedAsset.address, amountBigInt === maxUint256 ? maxUint256 : amountBigInt],
      });
    } catch (err: any) {
      addToast({ type: "error", title: "Repay Failed", message: err.shortMessage || err.message });
    }
  };

  const showRepayBtn = isApproveSuccess || repayState === "waiting" || repayState === "pending" || repayState === "success";

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-2">
        <label className="text-sm text-[var(--color-text-secondary)] font-medium">Select Debt to Repay</label>
        <select 
          className="w-full bg-[var(--color-bg-elevated)] border border-[var(--color-border)] rounded-lg px-4 py-3 outline-none focus:ring-2 focus:ring-[var(--color-accent)] transition-all cursor-pointer"
          value={selectedAssetIdx}
          onChange={(e) => {
            setSelectedAssetIdx(Number(e.target.value));
            setAmount("");
            setIsMax(false);
          }}
        >
          {assets.map((a: any, i: number) => (
            <option key={a.symbol} value={i}>{a.symbol}</option>
          ))}
        </select>
      </div>

      <div className="flex flex-col gap-2">
        <div className="flex justify-between items-end">
          <label className="text-sm text-[var(--color-text-secondary)] font-medium">Amount</label>
          <span className="text-xs text-[var(--color-red)] font-medium">
            Your Debt: {selectedAsset ? formatUnits(selectedAsset.debtBalance, selectedAsset.decimals) : "0"} {selectedAsset?.symbol}
          </span>
        </div>
        <div className="relative">
          <input
            type="number"
            placeholder="0.00"
            value={amount}
            onChange={(e) => {
              setAmount(e.target.value);
              setIsMax(false);
            }}
            className="w-full bg-[var(--color-bg-elevated)] border border-[var(--color-border)] rounded-lg pl-4 pr-16 py-3 outline-none focus:ring-2 focus:ring-[var(--color-accent)] transition-all font-mono text-lg"
          />
          <button
            onClick={handleMax}
            className="absolute right-2 top-1/2 -translate-y-1/2 text-xs font-bold text-[var(--color-accent)] hover:bg-[var(--color-accent)]/10 px-2 py-1 rounded transition-colors"
          >
            FULL
          </button>
        </div>
      </div>

      {!hasDebt && selectedAsset && (
        <div className="text-center text-sm text-[var(--color-text-secondary)] bg-[var(--color-bg-elevated)] rounded p-3">
          You don't have any {selectedAsset.symbol} debt to repay.
        </div>
      )}

      <div className="mt-4 flex flex-col gap-3">
        {!showRepayBtn ? (
          <TxButton
            idleText={`Approve ${selectedAsset?.symbol}`}
            txState={approveState}
            txHash={approveTxHash}
            onConfirm={handleApprove}
            disabled={isZero || !hasDebt}
          />
        ) : (
          <TxButton
            idleText="Repay"
            txState={repayState}
            txHash={repayTxHash}
            onConfirm={handleRepay}
            disabled={isZero || !hasDebt}
          />
        )}
      </div>
    </div>
  );
};
