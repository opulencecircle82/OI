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
  instructorIcon,
  manualIcon,
  qrSvg,
  reportIcon,
} from "../components";
import { asset, safety } from "../site";

export const metadata: Metadata = {
  title: "A320 Cabin Safety · Overdrive Interactive",
  description:
    "A320 Cabin Safety by Overdrive Interactive: where the emergency equipment is stowed in an A320 cabin, on a top view built from the Airbus figures, with a practice quiz and a drag-and-drop exam. Android and Windows.",
  openGraph: {
    title: "A320 Cabin Safety · Overdrive Interactive",
    description:
      "Emergency equipment locations in the A320 cabin, with a quiz and an exam. Android and Windows.",
    images: [asset("/screens/safety-chart.png")],
  },
};

const features = [
  {
    title: "A real A320 cabin",
    body: "A top view drawn from the Airbus A320 Aircraft Characteristics: doors 1L/1R and 2L/2R, four overwing exits, 180 seats, two galleys, three lavatories and the five attendant seats in their Airbus positions.",
    icon: "M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18",
  },
  {
    title: "45 items of emergency equipment",
    body: "Fire, medical, flotation, evacuation and signalling equipment, from the halon extinguishers and smoke hoods to the slides, megaphones, flashlights and ELT. Tap a location to see everything stowed there.",
    icon: "M12 2 4 6v6c0 5 3.5 8.5 8 10 4.5-1.5 8-5 8-10V6z",
  },
  {
    title: "Filter and highlight",
    body: "Show one category at a time, or tap an item to make every place that holds it light up on the chart. Zoom in with two fingers or the zoom keys.",
    icon: "M4 6h16M7 12h10M10 18h4",
  },
  {
    title: "QUIZ for practice",
    body: "Eight random items, one at a time: drag each one to where it is stowed and see right or wrong straight away. Points for the first and second try.",
    icon: "M9 12l2 2 4-4M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18",
  },
  {
    title: "EXAM with a score at the end",
    body: "Ten shuffled items, placed in any order on any of the 17 locations, with no hints. After SUBMIT: the score, the percentage and every answer with the correct place.",
    icon: "M9 11l3 3 8-8M20 12v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h9",
  },
  {
    title: "License code, offline use, automatic updates",
    body: "Activate once with a license code (SAFETY-xxxxxxxx, one device at a time); after that everything works offline. When online, the app checks for a new version at start and installs it in place.",
    icon: "M12 3v12m0 0-5-5m5 5 5-5M5 21h14",
  },
];

const shots: [string, string][] = [
  ["safety-popup.png", "Tap a location: everything stowed at the Door 1L crew station"],
  ["safety-quiz.png", "QUIZ: drag the item to the right location"],
  ["safety-exam.png", "EXAM: ten items, any order, no hints"],
  ["safety-result.png", "EXAM RESULT: score, percentage and every answer"],
];

const steps = [
  "Scan the QR code with the tablet or phone (or tap DOWNLOAD APK).",
  'Open the downloaded file. If Android asks, allow "Install unknown apps" for your browser.',
  "Tap Install, open A320 Cabin Safety and enter your license code (SAFETY-xxxxxxxx; internet needed once).",
  "Open LOCATIONS to learn, then QUIZ and EXAM to test yourself.",
];

const windowsSteps = [
  "Download the Setup file and run it.",
  'If Windows SmartScreen appears, choose "More info" then "Run anyway" (the installer is not code-signed).',
  "Open A320 Cabin Safety from the Start menu or the desktop and enter your license code.",
];

const notice: [string, string][] = [
  [
    "NOT AN APPROVED TRAINING DEVICE",
    "A320 Cabin Safety is not approved by Airbus, FAA, EASA, CAAP or any civil aviation authority and is not part of any aircraft or airline system.",
  ],
  [
    "NO AFFILIATION",
    "\"A320\" and related aircraft trademarks belong to Airbus. Overdrive Interactive is an independent entity with no official endorsement or affiliation with Airbus or any airline.",
  ],
  [
    "TYPICAL LAYOUT ONLY",
    "The chart shows a typical A320 single-class cabin of 180 seats. The kind, number and stowage of emergency equipment differ between airlines and aircraft; the airline's approved manuals and on-board equipment chart always take precedence.",
  ],
  [
    "LICENSE",
    "A320 Cabin Safety needs a license code (SAFETY-xxxxxxxx). Activation needs an internet connection once; each code works on one device at a time.",
  ],
];

export default async function SafetyPage() {
  const qr = await qrSvg(safety.apkUrl);
  return (
    <div className="radar">
      <SiteHeader
        active="safety"
        sections={[
          ["#features", "Features"],
          ["#documents", "Documents"],
          ["#gallery", "Screens"],
          ["#download", "Download"],
          ["#notice", "Notice"],
        ]}
      />

      <main>
        {/* Hero */}
        <section className="mx-auto grid max-w-6xl items-center gap-12 px-4 pt-10 pb-20 sm:px-8 lg:grid-cols-[1fr_1.3fr] lg:pt-16">
          <div className="text-center lg:text-left">
            <p className="font-mono text-xs font-bold tracking-[0.3em] text-cyan">
              CABIN CREW · EMERGENCY EQUIPMENT
            </p>
            <h1 className="mt-3 text-4xl leading-[1.1] font-extrabold sm:text-5xl">
              A320 Cabin Safety
            </h1>
            <p className="mt-5 text-lg leading-relaxed text-silver">
              Learn where every piece of emergency equipment is stowed in the
              A320 cabin, then test yourself with a quiz and a drag-and-drop
              exam.
            </p>
            <div className="mt-8 flex flex-col flex-wrap justify-center gap-3 sm:flex-row lg:justify-start">
              <DownloadButton href={safety.apkUrl} />
              <WindowsButton href={safety.windowsUrl} />
            </div>
            <p className="mt-4 text-xs text-silver/70">
              v{safety.version} · Android 7.0+ tablet or phone · Windows 10 / 11 PC (64-bit)
            </p>
          </div>
          <ScreenFrame
            src="safety-chart.png"
            alt="A320 Cabin Safety: the A320 cabin with the emergency equipment locations"
            width={1264}
            height={681}
            priority
          />
        </section>

        {/* Features */}
        <section id="features" className="mx-auto max-w-6xl scroll-mt-8 px-4 pb-20 sm:px-8">
          <SectionTitle kicker="FEATURES" title="Learn it, practise it, prove it" />
          <div className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {features.map((f) => (
              <div key={f.title} className="rounded-2xl border border-line bg-panel/70 p-6">
                <Icon d={f.icon} className="size-8 text-cyan" />
                <h3 className="mt-4 text-lg font-extrabold">{f.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-silver">{f.body}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Documents */}
        <section id="documents" className="mx-auto max-w-6xl scroll-mt-8 px-4 pb-20 sm:px-8">
          <SectionTitle kicker="DOCUMENTS" title="Manual, instructor guide and sources" />
          <PdfCard
            primary
            icon={manualIcon}
            iconClass="text-cyan"
            title="User Manual (PDF)"
            body="Installing on Android and Windows, the license code, the LOCATIONS chart, the QUIZ, the EXAM and its result, SETTINGS and updates, and troubleshooting."
            href={safety.manualPath}
          />
          <div className="mt-8">
            <PdfCard
              primary
              icon={instructorIcon}
              iconClass="text-fap-amber"
              title="Instructor Guide (PDF)"
              body="Classroom set-up and license codes, how to read the chart, a 45-minute lesson plan, discussion points by category, QUIZ and EXAM scoring, the full answer key and a printable assessment checklist."
              href={safety.guidePath}
            />
          </div>
          <PdfCard
            icon={reportIcon}
            iconClass="text-fap-green"
            title="Equipment Sources & A320 Conformance (PDF)"
            body="Where every item on the chart comes from: the Airbus A320 Aircraft Characteristics, the FAA and EASA rules, and what is typical airline practice."
            href={safety.reportPath}
          />
        </section>

        {/* Gallery */}
        <section id="gallery" className="border-y border-line bg-panel/40 py-20">
          <div className="mx-auto max-w-6xl px-4 sm:px-8">
            <SectionTitle kicker="SCREENS" title="A closer look" />
            <div className="mt-10 grid gap-8 md:grid-cols-2">
              {shots.map(([src, caption]) => (
                <figure key={src}>
                  <ScreenFrame src={src} alt={caption} width={1264} height={681} />
                  <figcaption className="mt-3 text-center text-sm text-silver">{caption}</figcaption>
                </figure>
              ))}
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
                Android APK · v{safety.version}
              </p>
            </div>
            <div>
              <SectionTitle kicker="DOWNLOAD" title="Scan to install on your device" />
              <Steps steps={steps} />
              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <DownloadButton href={safety.apkUrl} />
              </div>
            </div>
          </div>

          <div className="mt-6 grid items-center gap-6 rounded-3xl border border-line bg-panel/70 p-6 sm:p-10 md:grid-cols-[1fr_auto]">
            <div>
              <SectionTitle kicker="WINDOWS" title="Install on a Windows PC" />
              <Steps steps={windowsSteps} />
            </div>
            <div className="flex flex-col items-center gap-2">
              <WindowsButton href={safety.windowsUrl} />
              <span className="font-mono text-xs text-silver">
                Setup · v{safety.version} · Windows 10 / 11, 64-bit
              </span>
            </div>
          </div>
        </section>

        <Notice appName="A320 Cabin Safety" points={notice} />
      </main>

      <SiteFooter>
        A320 Cabin Safety shows a typical layout; always follow the airline&apos;s
        own equipment chart and procedures.
      </SiteFooter>
    </div>
  );
}
