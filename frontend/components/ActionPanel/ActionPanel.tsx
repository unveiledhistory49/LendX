"use client";

import React, { useState } from "react";
import { SupplyTab } from "./SupplyTab";
import { BorrowTab } from "./BorrowTab";
import { RepayTab } from "./RepayTab";
import { WithdrawTab } from "./WithdrawTab";
import { LiquidateTab } from "./LiquidateTab";
import { cn } from "../UI/TxButton";

export type ActionTab = "Supply" | "Borrow" | "Repay" | "Withdraw" | "Liquidate";
const TABS: ActionTab[] = ["Supply", "Borrow", "Repay", "Withdraw", "Liquidate"];

interface ActionPanelProps {
  assets: any[];
  poolAddress: `0x${string}`;
  userAccountData: readonly [bigint, bigint, bigint, bigint, bigint, bigint] | undefined;
  refetchAll: () => Promise<void>;
}

export const ActionPanel: React.FC<ActionPanelProps> = ({ 
  assets, 
  poolAddress, 
  userAccountData,
  refetchAll 
}) => {
  const [activeTab, setActiveTab] = useState<ActionTab>("Supply");

  return (
    <div className="bg-[var(--color-bg-card)] rounded-xl border border-[var(--color-border)] overflow-hidden flex flex-col h-full shadow-2xl">
      <div className="flex px-2 pt-2 gap-1 bg-[var(--color-bg-elevated)]/50 border-b border-[var(--color-border)] overflow-x-auto no-scrollbar">
        {TABS.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={cn(
              "px-4 py-3 text-sm font-medium rounded-t-lg transition-all whitespace-nowrap",
              activeTab === tab
                ? "bg-[var(--color-bg-card)] text-[var(--color-accent)] border-t border-l border-r border-[var(--color-border)] shadow-[0_-4px_10px_rgba(0,0,0,0.1)]"
                : "text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:bg-[var(--color-bg-elevated)]"
            )}
          >
            {tab}
          </button>
        ))}
      </div>

      <div className="p-6 flex-1 bg-[var(--color-bg-card)]">
        {activeTab === "Supply" && <SupplyTab assets={assets} poolAddress={poolAddress} refetchAll={refetchAll} />}
        {activeTab === "Borrow" && <BorrowTab assets={assets} poolAddress={poolAddress} userAccountData={userAccountData} refetchAll={refetchAll} />}
        {activeTab === "Repay" && <RepayTab assets={assets} poolAddress={poolAddress} refetchAll={refetchAll} />}
        {activeTab === "Withdraw" && <WithdrawTab assets={assets} poolAddress={poolAddress} userAccountData={userAccountData} refetchAll={refetchAll} />}
        {activeTab === "Liquidate" && <LiquidateTab assets={assets} poolAddress={poolAddress} refetchAll={refetchAll} />}
      </div>
    </div>
  );
};
