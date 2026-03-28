"use client";

import React from "react";
import { useAccount } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useLendX } from "../hooks/useLendX";
import { HealthFactorBar } from "../components/HealthFactorBar";
import { PositionsTable } from "../components/PositionsTable";
import { ActionPanel } from "../components/ActionPanel/ActionPanel";

export default function DashboardPage() {
  const { isConnected } = useAccount();
  const { poolAddress, userAccountData, assets, refetchAll } = useLendX();

  if (!isConnected) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[80vh] px-4">
        <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-[var(--color-accent)] to-blue-400 flex items-center justify-center text-white font-bold text-3xl shadow-xl shadow-[var(--color-accent)]/20 mb-8 transform -rotate-6">
          L
        </div>
        <h1 className="text-3xl font-bold tracking-tight text-[var(--color-text-primary)] mb-4 text-center">
          Welcome to LendX
        </h1>
        <p className="text-[var(--color-text-secondary)] text-center max-w-md mb-8">
          The non-custodial liquidity protocol. Supply assets to earn interest, or borrow against your collateral.
        </p>
        <ConnectButton />
      </div>
    );
  }

  // Calculate totals from userAccountData (collateral/debt base)
  const totalCollateral = userAccountData ? Number(userAccountData[0]) / 1e8 : 0;
  const totalDebt = userAccountData ? Number(userAccountData[1]) / 1e8 : 0;
  const netWorth = totalCollateral - totalDebt;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12 animate-in fade-in duration-500">
      
      {/* Top Stats & Health Factor Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
        <div className="lg:col-span-2 grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div className="bg-[var(--color-bg-card)] rounded-xl p-5 border border-[var(--color-border)] flex flex-col justify-center">
            <h3 className="text-sm text-[var(--color-text-secondary)] font-medium mb-1">Net Worth</h3>
            <span className="text-2xl font-bold tracking-tight">${netWorth.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2})}</span>
          </div>
          <div className="bg-[var(--color-bg-card)] rounded-xl p-5 border border-[var(--color-border)] flex flex-col justify-center">
            <h3 className="text-sm text-[var(--color-text-secondary)] font-medium mb-1">Total Supplied</h3>
            <span className="text-2xl font-bold tracking-tight">${totalCollateral.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2})}</span>
          </div>
          <div className="bg-[var(--color-bg-card)] rounded-xl p-5 border border-[var(--color-border)] flex flex-col justify-center">
            <h3 className="text-sm text-[var(--color-text-secondary)] font-medium mb-1">Total Borrowed</h3>
            <span className="text-2xl font-bold tracking-tight">${totalDebt.toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2})}</span>
          </div>
        </div>
        
        <div className="lg:col-span-1">
          <HealthFactorBar healthFactorRaw={userAccountData?.[5]} />
        </div>
      </div>

      {/* Main Two Column Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2">
          <PositionsTable assets={assets} />
        </div>
        <div className="lg:col-span-1">
          <div className="sticky top-24">
            <ActionPanel 
              assets={assets} 
              poolAddress={poolAddress} 
              userAccountData={userAccountData}
              refetchAll={refetchAll} 
            />
          </div>
        </div>
      </div>
      
    </div>
  );
}
