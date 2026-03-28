import React, { useState, useEffect } from "react";
import { useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits } from "viem";
import { LENDING_POOL_ABI } from "../../lib/abis";
import { TxButton, TransactionState } from "../UI/TxButton";
import { useToast } from "../UI/ToastProvider";
import { AlertCircle } from "lucide-react";
import { HealthFactorBar } from "../HealthFactorBar";

export const BorrowTab = ({ assets, poolAddress, userAccountData, refetchAll }: any) => {
  const { addToast } = useToast();
  const [selectedAssetIdx, setSelectedAssetIdx] = useState(0);
  const [amount, setAmount] = useState("");
  
  const selectedAsset = assets[selectedAssetIdx];
  
  const { writeContractAsync: borrowAsync, data: borrowTxHash, isPending: isBorrowWaiting } = useWriteContract();
  const { isLoading: isBorrowPending, isSuccess: isBorrowSuccess } = useWaitForTransactionReceipt({ hash: borrowTxHash });

  useEffect(() => {
    if (isBorrowSuccess) {
      addToast({ type: "success", title: `Borrowed ${selectedAsset?.symbol}`, txHash: borrowTxHash });
      setAmount("");
      refetchAll();
    }
  }, [isBorrowSuccess]);

  const amountBigInt = amount ? parseUnits(amount, selectedAsset?.decimals || 18) : 0n;
  const isZero = amountBigInt === 0n;

  // Simple stub for projected health factor.
  // Real calculation requires Oracle prices. Usually this is done via a dedicated view function or robust client-side math.
  // For the sake of the mockup UI, if user puts large amount to borrow, we simulate HF going down.
  const currentTotalDebtBase: bigint = userAccountData?.[1] || 0n;
  const currentTotalCollateralBase: bigint = userAccountData?.[0] || 0n;
  const ltv: bigint = userAccountData?.[4] || 0n; // out of 10000
  const currentLqThreshold: bigint = userAccountData?.[3] || 0n; // out of 10000

  // We simulate new health factor by adding a dummy value to totalDebtBase.
  // In a real app we'd convert `amountBigInt` to base currency using useOracle.
  // Assuming 1 token = 1e8 base approx to show UI changes:
  const amountBaseApproximation = (amountBigInt * 200000000n) / (10n ** BigInt(selectedAsset?.decimals || 18));
  
  const projectedDebtBase = currentTotalDebtBase + amountBaseApproximation;
  let projectedHF: bigint | undefined = undefined;
  
  if (currentTotalCollateralBase > 0n && projectedDebtBase > 0n && currentLqThreshold > 0n) {
    projectedHF = (currentTotalCollateralBase * currentLqThreshold * 10n**18n) / (projectedDebtBase * 10000n);
  }

  const isDANGEROUS = projectedHF !== undefined && projectedHF < (10n ** 18n); // < 1.0

  let borrowState: TransactionState = "idle";
  if (isBorrowWaiting) borrowState = "waiting";
  else if (isBorrowPending) borrowState = "pending";
  else if (isBorrowSuccess) borrowState = "success";

  const handleBorrow = async () => {
    try {
      if (!selectedAsset) return;
      await borrowAsync({
        address: poolAddress,
        abi: LENDING_POOL_ABI,
        functionName: "borrow",
        args: [selectedAsset.address, amountBigInt],
      });
    } catch (err: any) {
      addToast({ type: "error", title: "Borrow Failed", message: err.shortMessage || err.message });
    }
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-2">
        <label className="text-sm text-[var(--color-text-secondary)] font-medium">Select Asset to Borrow</label>
        <select 
          className="w-full bg-[var(--color-bg-elevated)] border border-[var(--color-border)] rounded-lg px-4 py-3 outline-none focus:ring-2 focus:ring-[var(--color-accent)] transition-all cursor-pointer"
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
          <label className="text-sm text-[var(--color-text-secondary)] font-medium">Amount</label>
        </div>
        <div className="relative">
          <input
            type="number"
            placeholder="0.00"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="w-full bg-[var(--color-bg-elevated)] border border-[var(--color-border)] rounded-lg pl-4 pr-4 py-3 outline-none focus:ring-2 focus:ring-[var(--color-accent)] transition-all font-mono text-lg"
          />
        </div>
      </div>

      {/* Projected HF */}
      {amountBigInt > 0n && (
        <div className="mt-2">
          <HealthFactorBar healthFactorRaw={userAccountData?.[5]} projectedHealthFactorRaw={projectedHF} />
        </div>
      )}

      {isDANGEROUS && (
        <div className="flex items-start gap-2 bg-[var(--color-red)]/10 text-[var(--color-red)] p-3 rounded-lg text-sm border border-[var(--color-red)]/20">
          <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
          <p>Borrowing this amount would make your position liquidatable (Health Factor &lt; 1.0).</p>
        </div>
      )}

      <div className="mt-4 flex flex-col gap-3">
        <TxButton
          idleText="Borrow"
          txState={borrowState}
          txHash={borrowTxHash}
          onConfirm={handleBorrow}
          disabled={isZero || isDANGEROUS}
          variant={isDANGEROUS ? "danger" : "primary"}
        />
      </div>
    </div>
  );
};
