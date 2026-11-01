import type { Metadata } from "next";
import {
  Icon,
  Notice,
  ScreenFrame,
  SectionTitle,
  SiteFooter,
  SiteHeader,
  commonNotice,
} from "../components";
import { asset, cabin } from "../site";

export const metadata: Metadata = {
  title: "A320 Cabin Trainer · Overdrive Interactive",
  description:
    "A320 Cabin Trainer by Overdrive Interactive: learn the emergency equipment on an interactive cabin map, quiz yourself, and explore the cabin entertainment system on an Android tablet or a Windows PC.",
  openGraph: {
    title: "A320 Cabin Trainer · Overdrive Interactive",
    description:
      "Interactive A320 emergency equipment map, drag-and-drop quiz and cabin entertainment demo for cabin-crew students. Android and Windows.",
    images: [asset("/screens/cabin-map.png")],
  },
};

const features = [
  {
    title: "Interactive cabin map",
    body: "A top-view A320 schematic with every emergency-equipment item placed in its zone: extinguishers, PBE, life vests, slide/rafts, megaphones, first-aid kits, torches and signalling devices. Filter by category, tap a marker and read what it is, how many are fitted and where they live.",
    icon: "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 5v5l4 2M2 12h4m12 0h4",
  },
  {
    title: "Drag-and-drop quiz",
    body: "Each round picks eight items from the catalog. Students drag an equipment chip onto the matching location on the cabin map; the answer is revealed on the map itself and the best score is saved on the device.",
    icon: "M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2M9 5a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2M9 5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2m-6 9 2 2 4-4",
  },
  {
    title: "IFE system diagram",
    body: "The cabin entertainment architecture as a static schematic for briefing: IFE Control / RCC, IFEC, ADB, FDB, SEB and the SDUs, with the CIDS branch — the same signal path the student sees on the demo screen.",
    icon: "M4 4h6v6H4zm10 0h6v6h-6zM7 10v4m10-4v4M7 14h10v6H7z",
  },
  {
    title: "Passenger demo",
    body: "A simulated seat-back screen: Movies, TV & Safety, Music channels, Flight Info with a moving map of the MNL–Cebu route, and Service for call and reading-light controls. Fully offline demo content, clearly marked DEMO.",
    icon: "M3 5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM8 21h8",
  },
  {
    title: "Instructor override",
    body: "A PIN-protected instructor panel takes over the demo: the PA announcement mutes the music channel while it plays, and best scores can be reset between classes.",
    icon: "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm7-3a7 7 0 1 1-14 0 7 7 0 0 1 14 0zm-9 8h4",
  },
  {
    title: "Built for the classroom tablet",
    body: "Landscape layout sized for a 10-inch tablet, touch targets of 24 dp and more, and everything runs offline — no accounts, no internet, nothing to configure between sessions.",
    icon: "M4 6h16v12H4zM2 9v6m20-6v6",
  },
];

const shots = [
  [
    "cabin-quiz.png",
    "Quiz round: drag the equipment chip onto its location on the cabin map",
  ],
  [
    "cabin-ife.png",
    "Cabin entertainment: IFE system schematic beside the passenger demo screen",
  ],
  [
    "cabin-flightinfo.png",
    "Flight Info on the demo screen: moving map with altitude, speed and time to destination",
  ],
];

const notice: [string, string][] = [
  ...commonNotice,
  [
    "SCHEMATIC ONLY",
    "The cabin diagram is a teaching schematic, not to scale. Equipment positions are typical-A320 training placements and are being reviewed against the school's own aircraft manual and cabin configuration before classroom use.",
  ],
  [
    "ACCURACY & LIABILITY",
    "While modeled for realistic interaction, operational variances may exist. This software must NOT be used for real-world aircraft operation or emergency-preparedness certification. Overdrive Interactive assumes no liability for misuse.",
  ],
];

export default function CabinPage() {
  return (
    <div className="radar">
      <SiteHeader
        active="cabin"
        sections={[
          ["#features", "Features"],
          ["#gallery", "Screens"],
          ["#notice", "Notice"],
        ]}
      />

      <main>
        {/* Hero */}
        <section className="mx-auto grid max-w-6xl items-center gap-12 px-4 pt-10 pb-20 sm:px-8 lg:grid-cols-[1fr_1.3fr] lg:pt-16">
          <div className="text-center lg:text-left">
            <p className="font-mono text-xs font-bold tracking-[0.3em] text-cyan">
              AIRBUS A320 · EMERGENCY EQUIPMENT · IFE
            </p>
            <h1 className="mt-3 text-4xl leading-[1.1] font-extrabold sm:text-5xl">
              A320 Cabin Trainer
            </h1>
            <p className="mt-5 text-lg leading-relaxed text-silver">
              Learn where the emergency equipment lives on the A320, prove it
              with a drag-and-drop quiz, and walk through the cabin
              entertainment system on a simulated seat-back screen.
            </p>
            <div className="mt-8 flex flex-col flex-wrap justify-center gap-3 sm:flex-row lg:justify-start">
              <a
                href="#features"
                className="inline-flex items-center justify-center gap-2 rounded-xl bg-cyan px-6 py-4 text-sm font-extrabold tracking-wider text-black hover:brightness-110"
              >
                <Icon d="M12 4v16m0-16 6 6m-6-6-6 6" />
                SEE WHAT IT DOES
              </a>
            </div>
            <p className="mt-4 text-xs text-silver/70">
              v{cabin.version} · Android 7.0+ tablet · Windows 10 / 11 PC
              (64-bit) · pilot deployment — ask your instructor for the build
            </p>
          </div>
          <ScreenFrame
            src="cabin-map.png"
            alt="A320 cabin map with emergency equipment markers"
            width={1280}
            height={689}
            priority
          />
        </section>

        {/* Features */}
        <section id="features" className="mx-auto max-w-6xl scroll-mt-8 px-4 pb-20 sm:px-8">
          <SectionTitle
            kicker="FEATURES"
            title="Two modules, one cabin"
            body="Emergency Equipment for the safety briefing and the test, Cabin Entertainment for the system walkthrough and the passenger demo."
          />
          <div className="mt-10 grid gap-5 md:grid-cols-3">
            {features.map((f) => (
              <div key={f.title} className="rounded-2xl border border-line bg-panel/70 p-6">
                <Icon d={f.icon} className="size-8 text-cyan" />
                <h3 className="mt-4 text-lg font-extrabold">{f.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-silver">{f.body}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Gallery */}
        <section id="gallery" className="border-y border-line bg-panel/40 py-20">
          <div className="mx-auto max-w-6xl px-4 sm:px-8">
            <SectionTitle
              kicker="SCREENS"
              title="What the student sees"
              body="Every screen runs offline on the classroom tablet. The instructor sits beside the student and drives the demo."
            />
            <div className="mt-10 grid gap-5 sm:grid-cols-2">
              {shots.map(([src, caption]) => (
                <figure key={src}>
                  <ScreenFrame src={src} alt={caption} width={1280} height={689} />
                  <figcaption className="mt-3 text-center text-sm text-silver">
                    {caption}
                  </figcaption>
                </figure>
              ))}
            </div>
          </div>
        </section>

        <Notice appName="A320 Cabin Trainer" points={notice} />
      </main>

      <SiteFooter>
        A320 Cabin Trainer is a classroom schematic. Equipment positions are
        typical-A320 training placements pending school review — never a
        substitute for the aircraft manual.
      </SiteFooter>
    </div>
  );
}
