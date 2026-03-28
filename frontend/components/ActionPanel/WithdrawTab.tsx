import React, { useState, useEffect } from "react";
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from "wagmi";
import { parseUnits, formatUnits, maxUint256 } from "viem";
import { LENDING_POOL_ABI } from "../../lib/abis";
import { TxButton, TransactionState } from "../UI/TxButton";
import { useToast } from "../UI/ToastProvider";
import { AlertCircle } from "lucide-react";
import { HealthFactorBar } from "../HealthFactorBar";

export const WithdrawTab = ({ assets, poolAddress, userAccountData, refetchAll }: any) => {
  const { address } = useAccount();
  const { addToast } = useToast();
  
  const [selectedAssetIdx, setSelectedAssetIdx] = useState(0);
  const [amount, setAmount] = useState("");
  const [isMax, setIsMax] = useState(false);
  
  const selectedAsset = assets[selectedAssetIdx];
  const hasSupply = selectedAsset?.aTokenBalance > 0n;

  const { writeContractAsync: withdrawAsync, data: withdrawTxHash, isPending: isWithdrawWaiting } = useWriteContract();
  const { isLoading: isWithdrawPending, isSuccess: isWithdrawSuccess } = useWaitForTransactionReceipt({ hash: withdrawTxHash });

  useEffect(() => {
    if (isWithdrawSuccess) {
      addToast({ type: "success", title: `Withdrew ${selectedAsset?.symbol}`, txHash: withdrawTxHash });
      setAmount("");
      setIsMax(false);
      refetchAll();
    }
  }, [isWithdrawSuccess]);

  const handleMax = () => {
    if (!selectedAsset) return;
    setAmount(formatUnits(selectedAsset.aTokenBalance, selectedAsset.decimals));
    setIsMax(true);
  };

  const amountBigInt = isMax ? maxUint256 : (amount ? parseUnits(amount, selectedAsset?.decimals || 18) : 0n);
  const isZero = amountBigInt === 0n;

  const currentTotalDebtBase: bigint = userAccountData?.[1] || 0n;
  const currentTotalCollateralBase: bigint = userAccountData?.[0] || 0n;
  const currentLqThreshold: bigint = userAccountData?.[3] || 0n; 

  const amountBaseApproximation = (amountBigInt === maxUint256 ? selectedAsset?.aTokenBalance : amountBigInt) * 200000000n / (10n ** BigInt(selectedAsset?.decimals || 18));
  
  const projectedCollateralBase = currentTotalCollateralBase > amountBaseApproximation ? currentTotalCollateralBase - amountBaseApproximation : 0n;
  let projectedHF: bigint | undefined = undefined;
  
  if (currentTotalDebtBase > 0n && currentLqThreshold > 0n) {
    projectedHF = (projectedCollateralBase * currentLqThreshold * 10n**18n) / (currentTotalDebtBase * 10000n);
  }

  const isDANGEROUS = projectedHF !== undefined && projectedHF < (10n ** 18n); 

  let withdrawState: TransactionState = "idle";
  if (isWithdrawWaiting) withdrawState = "waiting";
  else if (isWithdrawPending) withdrawState = "pending";
  else if (isWithdrawSuccess) withdrawState = "success";

  const handleWithdraw = async () => {
    try {
      if (!selectedAsset || !address) return;
      await withdrawAsync({
        address: poolAddress,
        abi: LENDING_POOL_ABI,
        functionName: "withdraw",
        args: [selectedAsset.address, amountBigInt, address],
      });
    } catch (err: any) {
      addToast({ type: "error", title: "Withdraw Failed", message: err.shortMessage || err.message });
    }
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-2">
        <label className="text-sm text-[var(--color-text-secondary)] font-medium">Select Asset to Withdraw</label>
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
          <span className="text-xs text-[var(--color-text-secondary)]">
            Supplied: {selectedAsset ? formatUnits(selectedAsset.aTokenBalance, selectedAsset.decimals) : "0"} {selectedAsset?.symbol}
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
            MAX
          </button>
        </div>
      </div>

      {!hasSupply && selectedAsset && (
        <div className="text-center text-sm text-[var(--color-text-secondary)] bg-[var(--color-bg-elevated)] rounded p-3">
          You don't have any {selectedAsset.symbol} supplied to withdraw.
        </div>
      )}

      {/* Projected HF */}
      {amountBigInt > 0n && currentTotalDebtBase > 0n && (
        <div className="mt-2">
          <HealthFactorBar healthFactorRaw={userAccountData?.[5]} projectedHealthFactorRaw={projectedHF} />
        </div>
      )}

      {isDANGEROUS && (
        <div className="flex items-start gap-2 bg-[var(--color-red)]/10 text-[var(--color-red)] p-3 rounded-lg text-sm border border-[var(--color-red)]/20">
          <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
          <p>Withdrawing this amount would make your position liquidatable (Health Factor &lt; 1.0).</p>
        </div>
      )}

      <div className="mt-4 flex flex-col gap-3">
        <TxButton
          idleText="Withdraw"
          txState={withdrawState}
          txHash={withdrawTxHash}
          onConfirm={handleWithdraw}
          disabled={isZero || !hasSupply || isDANGEROUS || !address}
          variant={isDANGEROUS ? "danger" : "primary"}
        />
      </div>
    </div>
  );
};
