import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "LendX Protocol | Premium DeFi Lending",
  description: "Experience the next generation of decentralized lending and borrowing with LendX.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body className="min-h-screen gradient-bg">
        <header className="sticky top-0 z-50 glass-panel">
          <div className="max-w-7xl mx-auto px-6 h-20 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-10 h-10 bg-cyan-500 rounded-lg flex items-center justify-center shadow-lg shadow-cyan-500/20">
                <span className="text-black font-black text-xl">X</span>
              </div>
              <h1 className="text-2xl font-bold tracking-tighter text-white">
                Lend<span className="text-cyan-400">X</span>
              </h1>
            </div>

            <nav className="hidden md:flex items-center gap-8">
              <a href="#" className="text-sm font-medium text-white/70 hover:text-white transition-colors">Markets</a>
              <a href="#" className="text-sm font-medium text-white/70 hover:text-white transition-colors">Dashboard</a>
              <a href="#" className="text-sm font-medium text-white/70 hover:text-white transition-colors">Analytics</a>
            </nav>

            <div className="text-xs font-semibold text-white/60">Wallet controls load on dashboard</div>
          </div>
        </header>

        <main className="max-w-7xl mx-auto p-6">{children}</main>

        <footer className="mt-20 border-t border-zinc-800 py-12 px-6">
          <div className="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-8">
            <div className="flex items-center gap-2 grayscale hover:grayscale-0 transition-all opacity-50 hover:opacity-100">
              <div className="w-6 h-6 bg-cyan-500 rounded flex items-center justify-center">
                <span className="text-black font-black text-xs">X</span>
              </div>
              <span className="text-lg font-bold">LendX</span>
            </div>
            <p className="text-white/40 text-sm">© 2026 LendX Protocol. Built with high-fidelity for decentralized finance.</p>
          </div>
        </footer>
      </body>
    </html>
  );
}
