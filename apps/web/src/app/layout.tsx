import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "TH7 Enterprise Suite | Workspace",
  description: "Workspace empresarial TH7 Enterprise Suite",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}