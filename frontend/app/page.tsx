'use client';

import React from 'react';
import { StatCard } from '@/components/StatCard';
import { HealthFactorBar } from '@/components/HealthFactorBar';
import { AssetTable } from '@/components/AssetTable';
import { TrendingUp, ShieldCheck, Zap, Activity } from 'lucide-react';

export default function Home() {
  return (
    <div className="space-y-10 py-4">
      {/* Hero / Hero Stats */}
      <section className="flex flex-col lg:flex-row gap-8 items-start">
        <div className="flex-1 space-y-4">
          <h2 className="text-4xl font-black text-white tracking-tighter leading-none">
            Your Protocol <span className="gradient-text tracking-normal">Dashboard</span>
          </h2>
          <p className="text-white/50 text-base max-w-xl">
            Manage your collateral, monitor health factors, and access instant liquidity across all supported LendX markets with optimized capital efficiency.
          </p>
        </div>
        
        <div className="w-full lg:w-96 glass-card p-6 border-cyan-500/20 shadow-cyan-500/5">
          <HealthFactorBar value={1.85} />
          <div className="mt-6 pt-6 border-t border-white/5 grid grid-cols-2 gap-4">
            <div>
              <div className="text-[10px] font-bold text-white/30 uppercase tracking-widest">Borrow Power</div>
              <div className="text-lg font-bold text-white">62.5%</div>
            </div>
            <div>
              <div className="text-[10px] font-bold text-white/30 uppercase tracking-widest">Liquidation at</div>
              <div className="text-lg font-bold text-rose-400">$1,940.20</div>
            </div>
          </div>
        </div>
      </section>

      {/* Stats Grid */}
      <section className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard 
          label="Total Net Worth" 
          value="$125,402.00" 
          icon={<Zap size={18} />}
          trend="12% vs last week"
          trendUp={true}
        />
        <StatCard 
          label="Total Collateral" 
          value="$184,200.00" 
          icon={<ShieldCheck size={18} />}
        />
        <StatCard 
          label="Total Debt" 
          value="$58,798.00" 
          icon={<Activity size={18} />}
          trend="2.4% vs last week"
          trendUp={false}
        />
        <StatCard 
          label="Total Earned" 
          value="$1,245.80" 
          icon={<TrendingUp size={18} />}
          trendUp={true}
          trend="8.1% all time"
        />
      </section>

      {/* Main Market Table */}
      <section>
        <AssetTable />
      </section>
      
      {/* Protocol Quick Links */}
      <section className="grid grid-cols-1 md:grid-cols-3 gap-6 opacity-80 hover:opacity-100 transition-opacity">
        <div className="glass-card p-6 flex items-center gap-4 cursor-pointer hover:bg-white/5">
          <div className="w-12 h-12 rounded-xl bg-cyan-500/10 flex items-center justify-center text-cyan-400">
            <Zap size={24} />
          </div>
          <div>
            <h4 className="font-bold">Flash Loans</h4>
            <p className="text-xs text-white/40">Access instant protocol liquidity.</p>
          </div>
        </div>
        
        <div className="glass-card p-6 flex items-center gap-4 cursor-pointer hover:bg-white/5">
          <div className="w-12 h-12 rounded-xl bg-purple-500/10 flex items-center justify-center text-purple-400">
            <TrendingUp size={24} />
          </div>
          <div>
            <h4 className="font-bold">Governance</h4>
            <p className="text-xs text-white/40">Vote on LendX improvement proposals.</p>
          </div>
        </div>
        
        <div className="glass-card p-6 flex items-center gap-4 cursor-pointer hover:bg-white/5">
          <div className="w-12 h-12 rounded-xl bg-rose-500/10 flex items-center justify-center text-rose-400">
            <ShieldCheck size={24} />
          </div>
          <div>
            <h4 className="font-bold">Security</h4>
            <p className="text-xs text-white/40">Audit reports and bug bounty info.</p>
          </div>
        </div>
      </section>
    </div>
  );
}
