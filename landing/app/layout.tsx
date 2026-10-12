import type { Metadata, Viewport } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import { asset, site } from "./site";

const inter = Inter({ variable: "--font-inter", subsets: ["latin"] });
const jetbrains = JetBrains_Mono({
  variable: "--font-jetbrains",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL(site.pageUrl),
  title: "Overdrive Interactive · A320 training apps",
  description:
    "Overdrive Interactive: A320 training apps for aviation students. A320 FAP Simulator for cabin crew and A320 MCDU Trainer for pilots.",
  openGraph: {
    title: "Overdrive Interactive · A320 training apps",
    description:
      "A320 FAP Simulator and A320 MCDU Trainer: realistic A320 panels on a tablet.",
    images: [asset("/screens/mcdu-dual.png")],
  },
};

export const viewport: Viewport = {
  themeColor: "#0a1520",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${inter.variable} ${jetbrains.variable} antialiased`}
    >
      <body className="min-h-screen font-sans">{children}</body>
    </html>
  );
}
