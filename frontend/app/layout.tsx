import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "HeliosCTA Monitoring",
  description:
    "Postgres-direct monitoring dashboards for HeliosCTA pipelines. Renders SQL at request time, no ingest layer.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased bg-slate-950 text-slate-100">{children}</body>
    </html>
  );
}
