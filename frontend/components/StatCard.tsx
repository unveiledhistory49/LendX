import React from 'react';

interface StatCardProps {
  label: string;
  value: string;
  icon?: React.ReactNode;
  trend?: string;
  trendUp?: boolean;
}

export const StatCard = ({ label, value, icon, trend, trendUp }: StatCardProps) => {
  return (
    <div className="glass-card p-6 flex flex-col justify-between group hover:border-cyan-500/30 transition-all duration-500">
      <div className="flex justify-between items-start">
        <span className="text-xs font-bold text-white/50 uppercase tracking-widest leading-none">{label}</span>
        {icon && <div className="text-white/20 group-hover:text-cyan-400 transition-colors">{icon}</div>}
      </div>
      <div className="mt-4 flex flex-col">
        <span className="text-3xl font-black text-white tracking-tight">{value}</span>
        {trend && (
          <span className={`text-[10px] mt-1 font-bold ${trendUp ? 'text-emerald-400' : 'text-rose-400'}`}>
            {trendUp ? '↗' : '↘'} {trend}
          </span>
        )}
      </div>
    </div>
  );
};
