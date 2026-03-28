"use client";

import React from "react";
import { Loader2, CheckCircle, ExternalLink } from "lucide-react";
import clsx from "clsx";
import { twMerge } from "tailwind-merge";

export type TransactionState = "idle" | "waiting" | "pending" | "success" | "error";

interface TxButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  txState?: TransactionState;
  txHash?: string;
  idleText?: string;
  onConfirm?: () => void;
  variant?: "primary" | "danger" | "outline";
}

export function cn(...inputs: (string | undefined | null | false)[]) {
  return twMerge(clsx(inputs));
}

export const TxButton: React.FC<TxButtonProps> = ({
  txState = "idle",
  txHash,
  idleText = "Submit",
  onConfirm,
  variant = "primary",
  className,
  disabled,
  ...props
}) => {
  const isActionable = txState === "idle" || txState === "error" || txState === "success";
  const overrideDisabled = !isActionable || disabled;

  let btnContent = <>{idleText}</>;
  if (txState === "waiting") {
    btnContent = (
      <>
        <Loader2 className="w-4 h-4 animate-spin mr-2" />
        Confirm in wallet...
      </>
    );
  } else if (txState === "pending") {
    btnContent = (
      <>
        <Loader2 className="w-4 h-4 animate-spin mr-2" />
        Processing...
      </>
    );
  } else if (txState === "success") {
    btnContent = (
      <>
        <CheckCircle className="w-4 h-4 mr-2" />
        Success
      </>
    );
  }

  const baseStyles = "w-full py-3 px-4 rounded-lg font-medium tracking-wide transition-all transform active:scale-[0.98] disabled:active:scale-100 flex items-center justify-center outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-[var(--color-bg-primary)]";
  
  const variantStyles = {
    primary: "bg-[var(--color-accent)] text-white hover:bg-[var(--color-accent-hover)] disabled:bg-[var(--color-accent-disabled)] disabled:opacity-70 disabled:cursor-not-allowed focus:ring-[var(--color-accent)]",
    danger: "bg-[var(--color-red)] text-white hover:bg-red-600 disabled:opacity-50 disabled:cursor-not-allowed focus:ring-[var(--color-red)]",
    outline: "bg-transparent border border-[var(--color-border)] text-white hover:bg-[var(--color-bg-elevated)] disabled:opacity-50 disabled:cursor-not-allowed focus:ring-[var(--color-border)]"
  };

  return (
    <div className="flex flex-col gap-2 w-full">
      <button
        type="button"
        onClick={onConfirm}
        disabled={overrideDisabled}
        className={cn(baseStyles, variantStyles[variant], className)}
        {...props}
      >
        {btnContent}
      </button>
      
      {txState === "pending" && txHash && (
        <a
          href={`https://sepolia.etherscan.io/tx/${txHash}`}
          target="_blank"
          rel="noopener noreferrer"
          className="text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-accent)] flex items-center justify-center gap-1 transition-colors"
        >
          View on Etherscan <ExternalLink className="w-3 h-3" />
        </a>
      )}
    </div>
  );
};
