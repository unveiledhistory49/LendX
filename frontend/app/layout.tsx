import "./globals.css";
import "@rainbow-me/rainbowkit/styles.css";
import { Providers } from "./providers";
import { Header } from "../components/Header";
import { ToastProvider } from "../components/UI/ToastProvider";

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="bg-[var(--color-bg-primary)] text-[var(--color-text-primary)] min-h-screen flex flex-col antialiased">
        <Providers>
          <ToastProvider>
            <Header />
            <main className="flex-1 w-full relative">
              {children}
            </main>
          </ToastProvider>
        </Providers>
      </body>
    </html>
  );
}
