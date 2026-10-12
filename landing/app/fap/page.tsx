import type { Metadata } from "next";
import {
  DownloadButton,
  Icon,
  Notice,
  ScreenFrame,
  SectionTitle,
  SiteFooter,
  SiteHeader,
  Steps,
  commonNotice,
  downloadIcon,
  qrSvg,
} from "../components";
import { asset, fap } from "../site";

export const metadata: Metadata = {
  title: "A320 FAP Simulator · Overdrive Interactive",
  description:
    "A320 FAP Simulator by Overdrive Interactive: an Airbus A320 CIDS Flight Attendant Panel trainer for cabin crew students. Android tablet and Windows app.",
  openGraph: {
    title: "A320 FAP Simulator · Overdrive Interactive",
    description:
      "Train on a full replica of the A320 Flight Attendant Panel. Download the Android app.",
    images: [asset("/screens/lights.png")],
  },
};

const features = [
  {
    title: "Offline Ready",
    body: "Activate once online, then everything runs on the tablet, even with no internet in the classroom.",
    icon: "M3 3l18 18M8.5 8.5A5 5 0 0 0 6 18h11m3.4-1.6A4 4 0 0 0 18 10h-.5A6.5 6.5 0 0 0 10 5.2",
  },
  {
    title: "Authentic A320 CIDS Logic",
    body: "BRT / DIM 1 / DIM 2 lighting, slide arming, EVAC CMD and RESET, SMOKE RESET and real Airbus chimes.",
    icon: "M9 3v2m6-2v2M9 19v2m6-2v2M3 9h2m-2 6h2m14-6h2m-2 6h2M7 5h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2zm3 5h4v4h-4z",
  },
  {
    title: "Flight Attendant Training Drills",
    body: "Arm / disarm and cross-check, lavatory smoke, evacuation, PRAM announcements and CIDS fault scenarios.",
    icon: "M12 4 2 9l10 5 10-5-10-5zm-6 7.5V16c0 1.7 2.7 3 6 3s6-1.3 6-3v-4.5",
  },
];

const manualIcon =
  "M4 5a2 2 0 0 1 2-2h12v16H6a2 2 0 0 0-2 2V5zm0 16a2 2 0 0 1 2-2h12v2H6M8 7h6M8 11h6";

const reportIcon = "M9 11l3 3 8-8M20 12v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h9";

const pages = [
  ["STATUS", "Cabin overview of every system at a glance."],
  ["AUDIO", "4 boarding music channels, PRAM with MEMO / PLAY ALL, chimes."],
  ["LIGHTS", "BRT 100% · DIM 1 50% · DIM 2 10% per cabin zone."],
  ["DOORS / SLIDES", "8 exits. Open an armed door and the slide deploys."],
  ["TEMP", "FWD / AFT zones: ±2.5 °C fine adjustment of the cockpit setting."],
  ["WATER / WASTE", "200 L potable water, 170 L waste, lavatory status."],
  ["SMOKE", "LAV A / D / E detectors, SMOKE RESET, auto-clear when smoke is gone."],
  ["SEAT SETTING", "Inhibit call buttons or reading lights per seat, passenger calls."],
  ["SYSTEM INFO", "CIDS directors, CAPT / CAPT & PURS selector, fault drills."],
  ["CABIN PROG", "Move cabin zones between classes and save to the CAM."],
  ["LAYOUT SELECT", "Load 1-, 2- or 3-class CAM layouts."],
  ["LEVEL ADJUST", "Announcement and chime levels per zone, -6 to +6 dB."],
  ["SW LOAD / FAP SET-UP", "Software loading, brightness, loudspeaker, key click."],
];

const hardKeys = [
  ["EVAC CMD", "red"],
  ["EVAC RESET", "red"],
  ["EMER", "amber"],
  ["PED POWER", "green"],
  ["LIGHTS MAIN", "green"],
  ["LAV MAINT", "green"],
  ["SCREEN LOCK", "amber"],
  ["SMOKE RESET", "red"],
  ["FAP RESET", "amber"],
  ["PAX SYS", "green"],
] as const;

const shots = [
  ["doors.png", "Slide deployed after opening an armed door"],
  ["smoke.png", "Lavatory smoke alert with crew actions"],
  ["audio.png", "PRAM announcements and cabin chimes"],
  ["evac.png", "Evacuation command active"],
];

const steps = [
  "Scan the QR code with the tablet camera, or tap Download APK.",
  'Allow "Install unknown apps" for your browser when Android asks.',
  fap.licensing
    ? "Open the app, enter your license code (internet needed once), and hold the tablet in landscape."
    : "Open the app and hold the tablet in landscape.",
];

const windowsSteps = [
  "Download the Setup and open it.",
  'If Windows shows "Windows protected your PC", click More info, then Run anyway.',
  "Follow the Setup (Next, accept the notice, Install). A desktop shortcut is created.",
  "Open A320 FAP Simulator and enter your license code (internet needed once).",
];

const notice: [string, string][] = [
  ...commonNotice,
  [
    "ACCURACY & LIABILITY",
    "While modeled for realistic interaction, operational variances may exist. This software must NOT be used for real-world aircraft operation, checklist validation, or actual emergency procedures. Overdrive Interactive assumes no liability for misuse.",
  ],
];

export default async function FapPage() {
  const qr = await qrSvg(fap.apkUrl);

  return (
    <div className="radar">
      <SiteHeader
        active="fap"
        sections={[
          ["#features", "Features"],
          ["#tutorial", "Tutorial"],
          [fap.manualPath, "Manual"],
          ["#panel", "The Panel"],
          ["#download", "Download"],
          ["#notice", "Notice"],
        ]}
      />

      <main>
        {/* Hero */}
        <section className="mx-auto grid max-w-6xl items-center gap-12 px-4 pt-10 pb-20 sm:px-8 lg:grid-cols-[1fr_1.15fr] lg:pt-16">
          <div className="text-center lg:text-left">
            <p className="font-mono text-xs font-bold tracking-[0.3em] text-cyan">
              AIRBUS A320 · CIDS · FAP
            </p>
            <h1 className="mt-3 text-4xl leading-[1.1] font-extrabold sm:text-5xl">
              A320 FAP Simulator
            </h1>
            <p className="mt-5 text-lg leading-relaxed text-silver">
              Train on a full replica of the Airbus A320 Flight Attendant
              Panel: cabin lighting, doors and slides, PRAM announcements,
              water/waste, lavatory smoke and evacuation signalling.
            </p>
            <div className="mt-8 flex flex-col flex-wrap justify-center gap-3 sm:flex-row lg:justify-start">
              <DownloadButton href={fap.apkUrl} />
              <WindowsButton />
              <a
                href="#tutorial"
                className="inline-flex items-center justify-center gap-2 rounded-xl border border-silver/60 px-6 py-4 text-sm font-extrabold tracking-wider hover:border-white hover:bg-white/5"
              >
                <Icon d="M8 5v14l11-7z" />
                WATCH TUTORIAL
              </a>
            </div>
            <a
              href={fap.manualPath}
              className="mt-4 inline-flex items-center gap-2 text-sm font-bold text-cyan hover:underline"
            >
              <Icon d={manualIcon} className="size-4" />
              User Manual (PDF) — every function explained
            </a>
            <p className="mt-4 text-xs text-silver/70">
              v{fap.version} · Android 7.0+ tablet · Windows 10 / 11 PC (64-bit)
            </p>
          </div>

          <ScreenFrame
            src="lights.png"
            alt="FAP cabin lighting page with A320 fuselage diagram"
            priority
          />
        </section>

        {/* Features */}
        <section id="features" className="mx-auto max-w-6xl scroll-mt-8 px-4 pb-20 sm:px-8">
          <div className="grid gap-5 md:grid-cols-3">
            {features.map((f) => (
              <div
                key={f.title}
                className="rounded-2xl border border-line bg-panel/70 p-6"
              >
                <Icon d={f.icon} className="size-8 text-cyan" />
                <h3 className="mt-4 text-lg font-extrabold">{f.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-silver">
                  {f.body}
                </p>
              </div>
            ))}
          </div>
        </section>

        {/* Tutorial */}
        <section id="tutorial" className="mx-auto max-w-6xl scroll-mt-8 px-4 pb-20 sm:px-8">
          <SectionTitle
            kicker="TUTORIAL"
            title="See every function in action"
            body="A full walk-through of the panel, page by page: lighting, audio and PRAM, doors and slides, water/waste, smoke and evacuation."
          />
          <div className="mt-8 overflow-hidden rounded-2xl border border-line bg-black shadow-[0_20px_60px_rgb(0_0_0/0.6)]">
            <iframe
              className="aspect-video w-full"
              src={`https://www.youtube-nocookie.com/embed/${fap.tutorialId}?rel=0`}
              title="A320 FAP Simulator tutorial"
              allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              referrerPolicy="strict-origin-when-cross-origin"
              allowFullScreen
              loading="lazy"
            />
          </div>
          <a
            href={fap.tutorialUrl}
            className="mt-3 inline-block text-sm font-bold text-cyan hover:underline"
          >
            Watch on YouTube →
          </a>

          <div className="mt-8 grid items-center gap-5 rounded-2xl border border-line bg-panel/70 p-6 sm:grid-cols-[auto_1fr_auto]">
            <Icon d={manualIcon} className="size-10 text-cyan" />
            <div>
              <h3 className="text-lg font-extrabold">User Manual (PDF)</h3>
              <p className="mt-1 text-sm leading-relaxed text-silver">
                42 pages: every page, key and hard key explained with
                screenshots, plus step-by-step training drills and
                troubleshooting.
              </p>
            </div>
            <a
              href={fap.manualPath}
              className="inline-flex items-center justify-center gap-2 rounded-xl bg-cyan px-6 py-4 text-sm font-extrabold tracking-wider text-black hover:brightness-110"
            >
              <Icon d={downloadIcon} />
              DOWNLOAD PDF
            </a>
          </div>

          <div className="mt-4 grid items-center gap-5 rounded-2xl border border-line bg-panel/70 p-6 sm:grid-cols-[auto_1fr_auto]">
            <Icon d={reportIcon} className="size-10 text-fap-green" />
            <div>
              <h3 className="text-lg font-extrabold">
                Feature Sources &amp; A320 Conformance (PDF)
              </h3>
              <p className="mt-1 text-sm leading-relaxed text-silver">
                Where every feature comes from and how it compares with the
                real A320 CIDS Flight Attendant Panel, with the sources used.
              </p>
            </div>
            <a
              href={fap.reportPath}
              className="inline-flex items-center justify-center gap-2 rounded-xl border border-cyan px-6 py-4 text-sm font-extrabold tracking-wider text-cyan hover:bg-cyan/10"
            >
              <Icon d={downloadIcon} />
              DOWNLOAD PDF
            </a>
          </div>
        </section>

        {/* The panel */}
        <section id="panel" className="border-y border-line bg-panel/40 py-20">
          <div className="mx-auto max-w-6xl px-4 sm:px-8">
            <SectionTitle
              kicker="THE PANEL"
              title="Every page of the classic CIDS FAP"
              body="Follows the real A320: grey keys are available, green is selected, amber is caution and red is alarm. Dashed TRAINER boxes let the instructor simulate what happens away from the panel."
            />
            <div className="mt-10 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {pages.map(([name, desc]) => (
                <div
                  key={name}
                  className="rounded-xl border border-line bg-ink/60 p-4"
                >
                  <div className="font-mono text-sm font-bold text-fap-green">
                    {name}
                  </div>
                  <p className="mt-1.5 text-sm text-silver">{desc}</p>
                </div>
              ))}
            </div>

            <div className="mt-10 rounded-2xl bg-gradient-to-b from-[#c2c8cf] to-[#8c95a0] p-5 text-[#1b232b]">
              <div className="mb-3 text-center text-[11px] font-extrabold tracking-[0.3em] text-[#4b535c]">
                HARD KEYS
              </div>
              <div className="grid grid-cols-5 gap-3 sm:grid-cols-10">
                {hardKeys.map(([label, led]) => (
                  <div key={label} className="flex flex-col items-center gap-1.5">
                    <span
                      className={`h-1 w-8 rounded ${
                        led === "red"
                          ? "bg-fap-red shadow-[0_0_8px] shadow-fap-red"
                          : led === "amber"
                            ? "bg-fap-amber shadow-[0_0_8px] shadow-fap-amber"
                            : "bg-fap-green shadow-[0_0_8px] shadow-fap-green"
                      }`}
                    />
                    <span
                      className={`h-9 w-full max-w-16 rounded-md border border-black/60 shadow-[0_3px_3px_rgb(0_0_0/0.5)] ${
                        label === "EVAC CMD"
                          ? "bg-gradient-to-b from-[#e53935] to-[#8e1010]"
                          : "bg-gradient-to-b from-[#4f5861] to-[#2b3138]"
                      }`}
                    />
                    <span className="text-center text-[10px] leading-tight font-extrabold">
                      {label}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            <div className="mt-10 grid gap-5 sm:grid-cols-2">
              {shots.map(([src, caption]) => (
                <figure key={src}>
                  <ScreenFrame src={src} alt={caption} />
                  <figcaption className="mt-3 text-center text-sm text-silver">
                    {caption}
                  </figcaption>
                </figure>
              ))}
            </div>
          </div>
        </section>

        {/* License */}
        {fap.licensing && (
        <section className="mx-auto max-w-6xl px-4 pb-4 sm:px-8">
          <div className="rounded-2xl border border-line bg-panel/70 p-6 sm:flex sm:items-center sm:gap-6">
            <Icon d="M15 7a4 4 0 1 1-3.9 5H4v3h2v2h3v-2h2.1A4 4 0 0 1 15 7z" className="size-10 shrink-0 text-cyan" />
            <div className="mt-3 sm:mt-0">
              <h3 className="text-lg font-extrabold">License code required</h3>
              <p className="mt-1 text-sm leading-relaxed text-silver">
                The first time the app opens, enter your license code
                (for example <span className="font-mono text-cyan">A320-k7Rm9Qx2</span>),
                exactly as given: capital and small letters matter.
                Activation needs an internet connection once. Each code works
                on one device only; after activation the simulator runs offline.
                Ask your instructor for a code.
              </p>
              <p className="mt-2 text-sm leading-relaxed text-silver">
                New tablet? On the old tablet tap ⚙ SETTINGS on the panel frame, then{" "}
                <b className="text-white">Deactivate &amp; Transfer License</b>, then
                enter the same code on the new one.
              </p>
              <p className="mt-2 text-sm leading-relaxed text-silver">
                No code yet? Try the free demo with code{" "}
                <span className="font-mono text-cyan">A320-DEMO</span> (no
                internet needed). The demo includes one lighting function
                (MAIN ON/OFF) and one audio function (boarding music); the
                other functions ask for a license code.
              </p>
            </div>
          </div>
        </section>
        )}

        {/* Download */}
        <section id="download" className="mx-auto max-w-6xl scroll-mt-8 px-4 py-20 sm:px-8">
          <div className="grid items-center gap-10 rounded-3xl border border-cyan/30 bg-panel/80 p-6 shadow-[0_0_60px_rgb(0_162_232/0.12)] sm:p-10 md:grid-cols-[auto_1fr]">
            <div className="mx-auto">
              <div
                className="size-52 rounded-2xl bg-white p-4 [&>svg]:size-full"
                role="img"
                aria-label="QR code linking to the Android app"
                dangerouslySetInnerHTML={{ __html: qr }}
              />
              <p className="mt-3 text-center font-mono text-sm font-bold text-cyan">
                Android APK · v{fap.version}
              </p>
            </div>
            <div>
              <SectionTitle
                kicker="DOWNLOAD"
                title="Scan to install on your tablet"
              />
              <Steps steps={steps} />
              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <DownloadButton href={fap.apkUrl} />
              </div>
            </div>
          </div>

          <div className="mt-6 grid items-center gap-6 rounded-3xl border border-line bg-panel/70 p-6 sm:p-10 md:grid-cols-[1fr_auto]">
            <div>
              <SectionTitle kicker="WINDOWS" title="Install on a Windows PC" />
              <Steps steps={windowsSteps} />
            </div>
            <div className="flex flex-col items-center gap-2">
              <WindowsButton />
              <span className="font-mono text-xs text-silver">
                Setup · v{fap.version} · Windows 10 / 11, 64-bit
              </span>
            </div>
          </div>
        </section>
        <Notice appName="A320 FAP Simulator" points={notice} />
      </main>

      <SiteFooter>
        A320 FAP Simulator is a training aid, not for operational use. Always
        follow your airline cabin crew manual.
      </SiteFooter>
    </div>
  );
}

function WindowsButton() {
  return (
    <a
      href={fap.windowsUrl}
      className="inline-flex items-center justify-center gap-2 rounded-xl border border-cyan px-6 py-4 text-sm font-extrabold tracking-wider text-cyan hover:bg-cyan/10"
    >
      <Icon d="M3 5.5 10 4.5v7H3zM11 4.4 21 3v8.5H11zM3 12.5h7v7l-7-1zM11 12.5h10V21l-10-1.4z" />
      DOWNLOAD FOR WINDOWS
    </a>
  );
}
