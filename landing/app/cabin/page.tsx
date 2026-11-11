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
  manualIcon,
  qrSvg,
} from "../components";
import { asset, cabin } from "../site";

export const metadata: Metadata = {
  title: "Cabin Entertainment · Overdrive Interactive",
  description:
    "Cabin Entertainment by Overdrive Interactive: a seatback entertainment system for Android and Windows. Welcome screen in eight languages, films and series, a 25-song music library and a moving map, all offline.",
  openGraph: {
    title: "Cabin Entertainment · Overdrive Interactive",
    description:
      "Seatback entertainment on a tablet or PC: films, series, music and a moving map. Android and Windows.",
    images: [asset("/screens/cabin-home.png")],
  },
};

const features = [
  {
    title: "Welcome in eight languages",
    body: "Like a real seatback after boarding: a welcome screen with round greetings (Hello, Mabuhay!, ¡Hola!, Bonjour, Ciao!, こんにちは, 안녕하세요, 你好). The home screen then greets the passenger in that language.",
    icon: "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm-8 10h16M12 2a15 15 0 0 1 0 20 15 15 0 0 1 0-20",
  },
  {
    title: "Films and series",
    body: "A streaming-style home with Movies, Series, Documentary and Classics shelves: open movies such as Spring, Sprite Fright and Tears of Steel, the Caminandes series, NASA documentaries and classics. Films start the moment you tap them.",
    icon: "M3 5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM10 7.5v5l4-2.5zM8 21h8",
  },
  {
    title: "25-song music library",
    body: "Jazz, chill, lo-fi, acoustic, vocal, pop, electronic, cinematic, classical and vintage songs. Genre filters, play / pause / next / previous, volume, and the next song starts by itself.",
    icon: "M9 18V5l12-2v13M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0zm12-2a3 3 0 1 1-6 0 3 3 0 0 1 6 0z",
  },
  {
    title: "Moving map",
    body: "Flight Info shows the flight from Paris to Barcelona on a map of France, Spain and the Mediterranean, with departure and arrival times, distance flown and to go, altitude, ground speed and outside temperature.",
    icon: "M9 4 3 6v14l6-2 6 2 6-2V4l-6 2-6-2zm0 0v14m6-12v14",
  },
  {
    title: "Seat service and system diagram",
    body: "Call the attendant or switch the reading light, and open a schematic of how a cabin entertainment system is wired, from the control panel and head-end to every seat.",
    icon: "M12 3v3m6.4-.4-2.1 2.1M21 12h-3M5.6 5.6l2.1 2.1M3 12h3m6 9a6 6 0 0 0 0-12 6 6 0 0 0 0 12z",
  },
  {
    title: "Offline, with automatic updates",
    body: "Everything is inside the app: no account and no internet needed. When the device is online, the app checks for a new version at start (and from SETTINGS) and installs it in place.",
    icon: "M12 3v12m0 0-5-5m5 5 5-5M5 21h14",
  },
];

const shots: [string, string][] = [
  ["cabin-welcome.png", "Welcome screen: choose a language to get started"],
  ["cabin-music.png", "Music library with genre filters and the now-playing card"],
  ["cabin-flightinfo.png", "Flight Info: moving map, progress strip and readouts"],
  ["cabin-tv.png", "TV: series, documentaries and classics"],
];

const steps = [
  "Scan the QR code with the tablet or phone (or tap DOWNLOAD APK).",
  'Open the downloaded file. If Android asks, allow "Install unknown apps" for your browser.',
  "Tap Install, then open Cabin Entertainment and pick a language.",
];

const windowsSteps = [
  "Download the Setup file and run it.",
  'If Windows SmartScreen appears, choose "More info" then "Run anyway" (the installer is not code-signed).',
  "Open Cabin Entertainment from the Start menu or the desktop.",
];

const notice: [string, string][] = [
  [
    "NOT AN AIRLINE OR AIRCRAFT SYSTEM",
    "Cabin Entertainment is not certified by Airbus, FAA, EASA, CAAP or any civil aviation authority and is not part of any aircraft or airline entertainment system.",
  ],
  [
    "NO AFFILIATION",
    "\"A320\" and related aircraft trademarks belong to Airbus. Overdrive Interactive is an independent entity with no official endorsement or affiliation with Airbus or any airline.",
  ],
  [
    "SIMULATED FLIGHT DATA",
    "The moving map, flight times and readouts are simulated for demonstration. Never use them for flight planning or navigation.",
  ],
  [
    "OPENLY LICENSED CONTENT",
    "All films and music are Creative Commons (CC BY / CC0) or public-domain works. Each title shows its credit on screen, and the full list of sources and licences is in the user manual.",
  ],
];

export default async function CabinPage() {
  const qr = await qrSvg(cabin.apkUrl);
  return (
    <div className="radar">
      <SiteHeader
        active="cabin"
        sections={[
          ["#features", "Features"],
          ["#manual", "Manual"],
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
              SEATBACK · FILMS · MUSIC · MOVING MAP
            </p>
            <h1 className="mt-3 text-4xl leading-[1.1] font-extrabold sm:text-5xl">
              Cabin Entertainment
            </h1>
            <p className="mt-5 text-lg leading-relaxed text-silver">
              The seatback entertainment system, on a tablet or a PC. Choose a
              language, then watch films and series, listen to music and follow
              the flight on the moving map.
            </p>
            <div className="mt-8 flex flex-col flex-wrap justify-center gap-3 sm:flex-row lg:justify-start">
              <DownloadButton href={cabin.apkUrl} />
              <WindowsButton href={cabin.windowsUrl} />
            </div>
            <p className="mt-4 text-xs text-silver/70">
              v{cabin.version} · Android 7.0+ tablet or phone · Windows 10 / 11 PC (64-bit)
            </p>
          </div>
          <ScreenFrame
            src="cabin-home.png"
            alt="Cabin Entertainment home screen with the featured film and the Movies shelf"
            width={1264}
            height={681}
            priority
          />
        </section>

        {/* Features */}
        <section id="features" className="mx-auto max-w-6xl scroll-mt-8 px-4 pb-20 sm:px-8">
          <SectionTitle kicker="FEATURES" title="Everything a passenger finds on the seatback" />
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

        {/* Manual */}
        <section id="manual" className="mx-auto max-w-6xl scroll-mt-8 px-4 pb-20 sm:px-8">
          <SectionTitle kicker="USER MANUAL" title="How to use Cabin Entertainment" />
          <PdfCard
            primary
            icon={manualIcon}
            iconClass="text-cyan"
            title="User Manual (PDF)"
            body="Installing on Android and Windows, the welcome screen and languages, home, movies and TV, the film player, the music library, Flight Info, Service, the system diagram, SETTINGS and updates, and the credits and licences of every film and song."
            href={cabin.manualPath}
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
                Android APK · v{cabin.version}
              </p>
            </div>
            <div>
              <SectionTitle kicker="DOWNLOAD" title="Scan to install on your device" />
              <Steps steps={steps} />
              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <DownloadButton href={cabin.apkUrl} />
              </div>
            </div>
          </div>

          <div className="mt-6 grid items-center gap-6 rounded-3xl border border-line bg-panel/70 p-6 sm:p-10 md:grid-cols-[1fr_auto]">
            <div>
              <SectionTitle kicker="WINDOWS" title="Install on a Windows PC" />
              <Steps steps={windowsSteps} />
            </div>
            <div className="flex flex-col items-center gap-2">
              <WindowsButton href={cabin.windowsUrl} />
              <span className="font-mono text-xs text-silver">
                Setup · v{cabin.version} · Windows 10 / 11, 64-bit
              </span>
            </div>
          </div>
        </section>

        <Notice appName="Cabin Entertainment" points={notice} />
      </main>

      <SiteFooter>
        Cabin Entertainment is not an airline or aircraft system. Flight data is
        simulated.
      </SiteFooter>
    </div>
  );
}
