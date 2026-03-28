"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";
import { AlertCircle } from "lucide-react";
import { useChainId } from "wagmi";
import Link from "next/link";
import { sepolia } from "viem/chains";

export const Header = () => {
  const chainId = useChainId();
  const isWrongNetwork = chainId !== sepolia.id;

  return (
    <header className="sticky top-0 z-40 w-full bg-[var(--color-bg-primary)] border-b border-[var(--color-border)] backdrop-blur-sm bg-opacity-90">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
        <div className="flex items-center gap-6">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-8 h-8 rounded bg-gradient-to-br from-[var(--color-accent)] to-blue-400 flex items-center justify-center text-white font-bold text-xl shadow-lg ring-1 ring-white/20 group-hover:shadow-[var(--color-accent)]/20 transition-all">
              L
            </div>
            <span className="text-xl font-bold tracking-tight text-[var(--color-text-primary)]">LendX</span>
          </Link>
          <nav className="hidden md:flex items-center gap-4">
            <Link href="/" className="text-sm font-medium text-[var(--color-text-primary)] hover:text-[var(--color-accent)] transition-colors">
              Dashboard
            </Link>
          </nav>
        </div>

        <div className="flex items-center gap-4">
          {isWrongNetwork && (
            <div className="hidden sm:flex items-center gap-2 bg-[var(--color-red)]/10 text-[var(--color-red)] px-3 py-1.5 rounded-full text-sm font-medium border border-[var(--color-red)]/20">
              <AlertCircle className="w-4 h-4" />
              Please connect to Sepolia
            </div>
          )}
          <ConnectButton 
            chainStatus="icon" 
            showBalance={false}
            accountStatus="avatar" 
          />
        </div>
      </div>
      
      {/* Mobile Network Warning */}
      {isWrongNetwork && (
        <div className="sm:hidden flex items-center justify-center gap-2 bg-[var(--color-red)]/10 text-[var(--color-red)] px-4 py-2 text-sm font-medium border-b border-[var(--color-red)]/20">
          <AlertCircle className="w-4 h-4" />
          Switch to Sepolia Network
        </div>
      )}
    </header>
  );
};
