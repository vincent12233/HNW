import type { Metadata } from "next";
import { DM_Sans } from "next/font/google";
import AppProviders from "@/components/AppProviders";
import "./globals.css";

const dmSans = DM_Sans({
  subsets: ["latin"],
  variable: "--font-admin-sans",
  display: "swap",
});

export const metadata: Metadata = {
  title: "India Trading Ops",
  description: "Role-isolated operations consoles for India Trading",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="zh-CN" className={`${dmSans.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col">
        <AppProviders>{children}</AppProviders>
      </body>
    </html>
  );
}
