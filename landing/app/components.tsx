import Image from "next/image";
import QRCode from "qrcode";
import type { ReactNode } from "react";
import { asset } from "./site";

export const downloadIcon = "M12 3v12m0 0-5-5m5 5 5-5M5 21h14";

/** QR code (SVG markup) for a download link. */
export function qrSvg(url: string) {
  return QRCode.toString(url, {
    type: "svg",
    margin: 0,
    color: { dark: "#0a1520", light: "#ffffff" },
  });
}

export function Logo({ size, glow = false }: { size: number; glow?: boolean }) {
  return (
    <span
      style={{ width: size, height: size, fontSize: size * 0.36 }}
      className={`grid shrink-0 place-items-center rounded-2xl border-2 border-cyan/60 bg-gradient-to-br from-[#0e2a3d] to-[#071019] font-mono font-extrabold text-cyan ${
        glow ? "shadow-[0_0_40px_rgb(0_162_232/0.45)]" : ""
      }`}
      aria-label="Overdrive Interactive"
    >
      OI
    </span>
  );
}

/** Top bar shared by every page: brand (home link) and the two apps. */
export function SiteHeader({
  active,
  sections,
}: {
  active?: "fap" | "mcdu";
  /** In-page links shown on wide screens. */
  sections?: [string, string][];
}) {
  const app = (key: "fap" | "mcdu", href: string, label: string) => (
    <a
      href={asset(href)}
      className={`rounded-lg px-3 py-1.5 text-sm font-bold ${
        active === key ? "bg-cyan text-black" : "text-silver hover:text-white"
      }`}
    >
      {label}
    </a>
  );
  return (
    <header className="mx-auto max-w-6xl px-4 py-5 sm:px-8">
      <div className="flex flex-wrap items-center gap-3">
        <a href={asset("/")} className="flex items-center gap-3">
          <Logo size={40} />
          <span className="text-sm font-extrabold tracking-[0.25em]">
            OVERDRIVE INTERACTIVE
          </span>
        </a>
        <nav className="ml-auto flex items-center gap-1">
          {app("fap", "/fap/", "A320 FAP")}
          {app("mcdu", "/mcdu/", "A320 MCDU")}
        </nav>
      </div>
      {sections && (
        <nav className="mt-4 hidden flex-wrap gap-7 text-sm text-silver md:flex">
          {sections.map(([href, label]) => (
            <a key={href} href={href} className="hover:text-white">
              {label}
            </a>
          ))}
        </nav>
      )}
    </header>
  );
}

export function SiteFooter({ children }: { children?: ReactNode }) {
  return (
    <footer className="border-t border-line px-4 py-8 text-center text-xs text-[#5e7184]">
      © Overdrive Interactive · Training aids for aviation students, not for
      operational use.
      {children && <div className="mt-2">{children}</div>}
    </footer>
  );
}

export function ScreenFrame({
  src,
  alt,
  priority = false,
  width = 1600,
  height = 1000,
}: {
  src: string;
  alt: string;
  priority?: boolean;
  width?: number;
  height?: number;
}) {
  return (
    <div className="overflow-hidden rounded-2xl border border-line bg-[#070d13] shadow-[0_20px_60px_rgb(0_0_0/0.6)]">
      <Image
        src={asset(`/screens/${src}`)}
        alt={alt}
        width={width}
        height={height}
        priority={priority}
        className="h-auto w-full"
      />
    </div>
  );
}

export function SectionTitle({
  kicker,
  title,
  body,
}: {
  kicker: string;
  title: string;
  body?: ReactNode;
}) {
  return (
    <div>
      <p className="font-mono text-xs font-bold tracking-[0.3em] text-cyan">
        {kicker}
      </p>
      <h2 className="mt-2 text-3xl font-extrabold">{title}</h2>
      {body && <p className="mt-3 max-w-3xl text-silver">{body}</p>}
    </div>
  );
}

export function Icon({ d, className = "size-5" }: { d: string; className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden
    >
      <path d={d} />
    </svg>
  );
}

export const manualIcon =
  "M4 5a2 2 0 0 1 2-2h12v16H6a2 2 0 0 0-2 2V5zm0 16a2 2 0 0 1 2-2h12v2H6M8 7h6M8 11h6";
export const reportIcon = "M9 11l3 3 8-8M20 12v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h9";
export const instructorIcon = "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm-7 9a7 7 0 0 1 14 0";

/** A PDF download row: icon, title, description and a DOWNLOAD PDF button. */
export function PdfCard({
  icon,
  iconClass,
  title,
  body,
  href,
  primary = false,
}: {
  icon: string;
  iconClass: string;
  title: ReactNode;
  body: ReactNode;
  href: string;
  primary?: boolean;
}) {
  return (
    <div className="mt-4 grid items-center gap-5 rounded-2xl border border-line bg-panel/70 p-6 sm:grid-cols-[auto_1fr_auto]">
      <Icon d={icon} className={`size-10 ${iconClass}`} />
      <div>
        <h3 className="text-lg font-extrabold">{title}</h3>
        <p className="mt-1 text-sm leading-relaxed text-silver">{body}</p>
      </div>
      <a
        href={href}
        className={
          primary
            ? "inline-flex items-center justify-center gap-2 rounded-xl bg-cyan px-6 py-4 text-sm font-extrabold tracking-wider text-black hover:brightness-110"
            : "inline-flex items-center justify-center gap-2 rounded-xl border border-cyan px-6 py-4 text-sm font-extrabold tracking-wider text-cyan hover:bg-cyan/10"
        }
      >
        <Icon d={downloadIcon} />
        DOWNLOAD PDF
      </a>
    </div>
  );
}

export function DownloadButton({ href, label = "DOWNLOAD APK" }: { href: string; label?: string }) {
  return (
    <a
      href={href}
      className="inline-flex items-center justify-center gap-2 rounded-xl bg-cyan px-6 py-4 text-sm font-extrabold tracking-wider text-black hover:brightness-110"
    >
      <Icon d={downloadIcon} />
      {label}
    </a>
  );
}

export function WindowsButton({ href }: { href: string }) {
  return (
    <a
      href={href}
      className="inline-flex items-center justify-center gap-2 rounded-xl border border-cyan px-6 py-4 text-sm font-extrabold tracking-wider text-cyan hover:bg-cyan/10"
    >
      <Icon d="M3 5.5 10 4.5v7H3zM11 4.4 21 3v8.5H11zM3 12.5h7v7l-7-1zM11 12.5h10V21l-10-1.4z" />
      DOWNLOAD FOR WINDOWS
    </a>
  );
}

/** Numbered install steps. */
export function Steps({ steps }: { steps: string[] }) {
  return (
    <ol className="mt-6 space-y-3">
      {steps.map((s, i) => (
        <li key={s} className="flex gap-3 text-silver">
          <span className="grid size-6 shrink-0 place-items-center rounded-full bg-cyan text-xs font-extrabold text-black">
            {i + 1}
          </span>
          {s}
        </li>
      ))}
    </ol>
  );
}

/** The important notice shown at the bottom of each app page. */
export function Notice({
  appName,
  points,
}: {
  appName: string;
  points: [string, string][];
}) {
  return (
    <section id="notice" className="mx-auto max-w-6xl scroll-mt-8 px-4 pb-20 sm:px-8">
      <div className="rounded-2xl border border-fap-amber/60 bg-panel/80 p-6 sm:p-8">
        <h2 className="text-xl font-extrabold tracking-wide text-fap-amber">
          IMPORTANT NOTICE &amp; DISCLAIMER
        </h2>
        <p className="mt-3 text-silver">
          This software ({appName}) is developed by Overdrive Interactive for
          academic, familiarization, and educational training purposes only.
        </p>
        <ol className="mt-4 space-y-3">
          {points.map(([title, body], i) => (
            <li key={title} className="flex gap-3 text-sm leading-relaxed text-silver">
              <span className="font-extrabold text-cyan">{i + 1}.</span>
              <span>
                <strong className="text-white">{title}:</strong> {body}
              </span>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}

/** Points shared by both apps' notices. */
export const commonNotice: [string, string][] = [
  [
    "NOT AN OFFICIALLY CERTIFIED FTD",
    "This application is a classroom supplement and is NOT certified by Airbus, FAA, EASA, CAAP, or any civil aviation authority for official type-rating or flight training credits.",
  ],
  [
    "NO AFFILIATION",
    "\"A320\" and related aircraft trademarks belong to Airbus. Overdrive Interactive is an independent entity with no official endorsement or affiliation with Airbus.",
  ],
];
