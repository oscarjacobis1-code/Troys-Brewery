import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Troy's Brewery Demo",
  description: "Interactive preview of Troy's Brewery ordering and operations platform.",
  other: { "codex-preview": "development" },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
