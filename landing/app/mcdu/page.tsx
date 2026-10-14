import type { Metadata } from "next";
import {
  DownloadButton,
  Icon,
  Notice,
  PdfCard,
  ScreenFrame,
  SectionTitle,
  SiteFooter,
  SiteHeader,
  Steps,
  WindowsButton,
  commonNotice,
  instructorIcon,
  qrSvg,
  reportIcon,
} from "../components";
import { asset, mcdu } from "../site";

export const metadata: Metadata = {
  title: "A320 MCDU Trainer · Overdrive Interactive",
  description:
    "A320 MCDU Trainer by Overdrive Interactive: practise the A320 MCDU, Navigation Display and weather radar on an Android tablet or phone, or a Windows PC.",
  openGraph: {
    title: "A320 MCDU Trainer · Overdrive Interactive",
    description:
      "Program the A320 MCDU, watch the flight on the ND and read the weather radar. Android and Windows.",
    images: [asset("/screens/mcdu-dual.png")],
  },
};

const features = [
  {
    title: "MCDU like the aircraft",
    body: "14-line display with the Airbus colour code, line select keys, scratchpad and CLR logic, and real messages such as NOT ALLOWED and FORMAT ERROR.",
    icon: "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zm2 4h10M7 11h10M7 15h6",
  },
  {
    title: "Navigation Display",
    body: "ROSE ILS / VOR / NAV, ARC and PLAN modes, 10 to 320 NM, CSTR / WPT / VOR.D / NDB / ARPT, and the temporary flight plan in yellow.",
    icon: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zm0 4v5l3 3",
  },
  {
    title: "Weather radar",
    body: "MultiScan panel: WX, WX+T, TURB and MAP, GAIN and TILT. A high tilt overshoots the storm; a low tilt paints the ground.",
    icon: "M4 15a8 8 0 0 1 16 0M7 15a5 5 0 0 1 10 0m-5 0 4-6",
  },
];

const pages = [
  ["INIT A / B", "FROM/TO, company route, ALTN, flight number, cost index, CRZ FL, weights and fuel."],
  ["F-PLN", "Insert and clear waypoints, discontinuities, speed and altitude constraints, (T/C) and (T/D)."],
  ["LAT REV / VERT REV", "NEXT WPT and NEW DEST with a yellow TMPY plan: *ERASE or INSERT*."],
  ["DIR TO", "Direct to any point from the present position, then INSERT."],
  ["PERF", "TAKE OFF V1 / VR / V2 with the disagree check, FLAPS/THS, FLEX, then CLB, CRZ, DES and APPR."],
  ["PROG", "Cruise level, optimum and maximum level, bearing and distance to any point."],
  ["RAD NAV", "VOR, ILS and ADF by identifier or frequency, with course."],
  ["FUEL PRED / DATA", "Fuel at destination and alternate, extra fuel, position monitor, aircraft status."],
];

const shots = [
  ["mcdu-tmpy.png", "LAT REV: the new waypoint shows as a yellow temporary flight plan"],
  ["mcdu-wxr-tilt.png", "Manual tilt too low: ground returns over the islands"],
  ["mcdu-dirto.png", "DIR TO from the present position"],
  ["mcdu-plan.png", "PLAN mode with the WPT option"],
  ["mcdu-faults.png", "Trainer faults: FM1 failed, GPS lost, weather radar system 1 failed"],
];

const steps = [
  "Scan the QR code with the tablet or phone camera, or tap Download APK.",
  'Allow "Install unknown apps" for your browser when Android asks.',
  "Open the app, enter your license code (internet needed once), and hold the device in landscape.",
];

const windowsSteps = [
  "Download the Setup and open it.",
  'If Windows shows "Windows protected your PC", click More info, then Run anyway.',
  "Follow the Setup (Next, accept the notice, Install). A desktop shortcut is created.",
  "Open A320 MCDU Trainer and enter your license code (internet needed once). On a PC you can type on the MCDU with the computer keyboard.",
];

const notice: [string, string][] = [
  ...commonNotice,
  [
    "TRAINING DATA ONLY",
    "All waypoints, navaids, frequencies, weather and performance figures are simplified or fictional training data. Airport positions are approximate. Never use them for flight planning or navigation.",
  ],
  [
    "ACCURACY & LIABILITY",
    "While modeled for realistic interaction, operational variances may exist. This software must NOT be used for real-world aircraft operation or flight preparation. Overdrive Interactive assumes no liability for misuse.",
  ],
];

export default async function McduPage() {
  const qr = await qrSvg(mcdu.apkUrl);
  return (
    <div className="radar">
      <SiteHeader
        active="mcdu"
        sections={[
          ["#features", "Features"],
          ["#tutorial", "Tutorial"],
          ["#pages", "MCDU pages"],
          ["#download", "Download"],
          ["#notice", "Notice"],
        ]}
      />

      <main>
        {/* Hero */}
        <section className="mx-auto grid max-w-6xl items-center gap-12 px-4 pt-10 pb-20 sm:px-8 lg:grid-cols-[1fr_1.3fr] lg:pt-16">
          <div className="text-center lg:text-left">
            <p className="font-mono text-xs font-bold tracking-[0.3em] text-cyan">
              AIRBUS A320 · MCDU · ND · WXR
            </p>
            <h1 className="mt-3 text-4xl leading-[1.1] font-extrabold sm:text-5xl">
              A320 MCDU Trainer
            </h1>
            <p className="mt-5 text-lg leading-relaxed text-silver">
              Program the A320 MCDU, watch the flight on the Navigation
              Display and learn to read the weather radar. Then fly the route
              and see the waypoints sequence.
            </p>
            <div className="mt-8 flex flex-col flex-wrap justify-center gap-3 sm:flex-row lg:justify-start">
              <DownloadButton href={mcdu.apkUrl} />
              <WindowsButton href={mcdu.windowsUrl} />
              <a
                href="#tutorial"
                className="inline-flex items-center justify-center gap-2 rounded-xl border border-silver/60 px-6 py-4 text-sm font-extrabold tracking-wider hover:border-white hover:bg-white/5"
              >
                <Icon d="M8 5v14l11-7z" />
                WATCH TUTORIAL
              </a>
            </div>
            <p className="mt-4 text-xs text-silver/70">
              v{mcdu.version} · Android 7.0+ tablet or phone · Windows 10 / 11 PC (64-bit)
            </p>
          </div>
          <ScreenFrame
            src="mcdu-dual.png"
            alt="MCDU flight plan page next to the Navigation Display with weather radar"
            width={1280}
            height={800}
            priority
          />
        </section>

        {/* Features */}
        <section id="features" className="mx-auto max-w-6xl scroll-mt-8 px-4 pb-20 sm:px-8">
          <div className="grid gap-5 md:grid-cols-3">
            {features.map((f) => (
              <div key={f.title} className="rounded-2xl border border-line bg-panel/70 p-6">
                <Icon d={f.icon} className="size-8 text-cyan" />
                <h3 className="mt-4 text-lg font-extrabold">{f.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-silver">{f.body}</p>
              </div>
            ))}
          </div>
          <div className="mt-5 rounded-2xl border border-dashed border-fap-amber/60 bg-panel/50 p-6">
            <h3 className="font-mono text-sm font-bold tracking-widest text-fap-amber">
              TRAINER
            </h3>
            <p className="mt-2 text-sm leading-relaxed text-silver">
              Press FLY to fly your flight plan from Manila (RPLL) to Cebu
              (RPVM) at ×1, ×4 or ×16 speed. Waypoints sequence on the F-PLN
              page, a discontinuity stops managed navigation, and RESET brings
              the aircraft back to the gate. Dashed boxes mark controls that
              exist only in the trainer.
            </p>
            <p className="mt-2 text-sm leading-relaxed text-silver">
              <b className="text-white">FAULTS</b> lets the instructor fail a
              system: FM1 or FM2 (single FMGC, PLEASE WAIT after the reset),
              IND, MCDU FAIL, GPS (GPS PRIMARY LOST, NAV ACCUR DOWNGRAD on the
              approach), weather radar system 1 or 2, VOR 1 and ILS.
            </p>
          </div>
        </section>

        {/* Tutorial */}
        <section id="tutorial" className="mx-auto max-w-6xl scroll-mt-8 px-4 pb-20 sm:px-8">
          <SectionTitle
            kicker="TUTORIAL"
            title="Set up a flight, fly it, read the radar"
            body="A seven-minute walk-through: INIT A and B, the flight plan, constraints and discontinuities, the temporary flight plan, take-off speeds, ND modes, the weather radar, DIR TO and the trainer faults."
          />
          <div className="mt-8 overflow-hidden rounded-2xl border border-line bg-black shadow-[0_20px_60px_rgb(0_0_0/0.6)]">
            <iframe
              className="aspect-video w-full"
              src={`https://www.youtube-nocookie.com/embed/${mcdu.tutorialId}?rel=0`}
              title="A320 MCDU Trainer tutorial"
              allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              referrerPolicy="strict-origin-when-cross-origin"
              allowFullScreen
              loading="lazy"
            />
          </div>
          <a
            href={mcdu.tutorialUrl}
            className="mt-3 inline-block text-sm font-bold text-cyan hover:underline"
          >
            Watch on YouTube →
          </a>

          <div className="mt-8">
            <PdfCard
              primary
              icon={instructorIcon}
              iconClass="text-fap-amber"
              title="Instructor Guide (PDF)"
              body="34 pages for the instructor: classroom set-up, license codes, quick reference, eight lesson plans with answer keys (including system faults), and an assessment checklist."
              href={mcdu.guidePath}
            />
          </div>
          <PdfCard
            icon={reportIcon}
            iconClass="text-fap-green"
            title="Feature Sources & A320 Conformance (PDF)"
            body="Where every feature comes from and how it compares with the real A320 MCDU, ND and weather radar, with the sources used."
            href={mcdu.reportPath}
          />
        </section>

        {/* Pages */}
        <section id="pages" className="border-y border-line bg-panel/40 py-20">
          <div className="mx-auto max-w-6xl px-4 sm:px-8">
            <SectionTitle
              kicker="MCDU PAGES"
              title="The pages a student uses first"
              body="White is for titles and prompts, blue for data you can change, green for active data, amber boxes for required entries, magenta for constraints and yellow for a temporary flight plan."
            />
            <div className="mt-10 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {pages.map(([name, desc]) => (
                <div key={name} className="rounded-xl border border-line bg-ink/60 p-4">
                  <div className="font-mono text-sm font-bold text-fap-green">{name}</div>
                  <p className="mt-1.5 text-sm text-silver">{desc}</p>
                </div>
              ))}
            </div>
            <div className="mt-10 grid gap-5 sm:grid-cols-2">
              {shots.map(([src, caption]) => (
                <figure key={src}>
                  <ScreenFrame src={src} alt={caption} width={1280} height={800} />
                  <figcaption className="mt-3 text-center text-sm text-silver">
                    {caption}
                  </figcaption>
                </figure>
              ))}
            </div>
            <figure className="mx-auto mt-10 max-w-3xl">
              <ScreenFrame
                src="mcdu-phone.png"
                alt="On a phone the keyboard sits beside the display"
                width={800}
                height={360}
              />
              <figcaption className="mt-3 text-center text-sm text-silver">
                On a phone the keyboard sits beside the display
              </figcaption>
            </figure>
          </div>
        </section>

        {/* License */}
        <section className="mx-auto max-w-6xl px-4 pt-20 pb-4 sm:px-8">
          <div className="rounded-2xl border border-line bg-panel/70 p-6 sm:flex sm:items-center sm:gap-6">
            <Icon
              d="M15 7a4 4 0 1 1-3.9 5H4v3h2v2h3v-2h2.1A4 4 0 0 1 15 7z"
              className="size-10 shrink-0 text-cyan"
            />
            <div className="mt-3 sm:mt-0">
              <h3 className="text-lg font-extrabold">License code required</h3>
              <p className="mt-1 text-sm leading-relaxed text-silver">
                The first time the app opens, enter your license code (for
                example <span className="font-mono text-cyan">MCDU-k7Rm9Qx2</span>),
                exactly as given: capital and small letters matter. Activation
                needs an internet connection once. Each code works on one
                device only. A320 FAP codes do not work in this app. Ask your
                instructor for a code.
              </p>
              <p className="mt-2 text-sm leading-relaxed text-silver">
                New device? On the old one tap ⚙ Settings, then{" "}
                <b className="text-white">Deactivate &amp; Transfer License</b>,
                then enter the same code on the new one.
              </p>
              <p className="mt-2 text-sm leading-relaxed text-silver">
                No code yet? Try the free demo with code{" "}
                <span className="font-mono text-cyan">MCDU-DEMO</span> (no
                internet needed): the INIT and F-PLN pages and the Navigation
                Display.
              </p>
            </div>
          </div>
        </section>

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
                Android APK · v{mcdu.version}
              </p>
            </div>
            <div>
              <SectionTitle kicker="DOWNLOAD" title="Scan to install on your device" />
              <Steps steps={steps} />
              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <DownloadButton href={mcdu.apkUrl} />
              </div>
            </div>
          </div>

          <div className="mt-6 grid items-center gap-6 rounded-3xl border border-line bg-panel/70 p-6 sm:p-10 md:grid-cols-[1fr_auto]">
            <div>
              <SectionTitle kicker="WINDOWS" title="Install on a Windows PC" />
              <Steps steps={windowsSteps} />
            </div>
            <div className="flex flex-col items-center gap-2">
              <WindowsButton href={mcdu.windowsUrl} />
              <span className="font-mono text-xs text-silver">
                Setup · v{mcdu.version} · Windows 10 / 11, 64-bit
              </span>
            </div>
          </div>
        </section>

        <Notice appName="A320 MCDU Trainer" points={notice} />
      </main>

      <SiteFooter>
        A320 MCDU Trainer uses fictional training data. Never use it for flight
        planning or navigation.
      </SiteFooter>
    </div>
  );
}
