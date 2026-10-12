import { Logo, ScreenFrame, SiteFooter, SiteHeader } from "./components";
import { asset, fap, mcdu } from "./site";

const apps = [
  {
    href: "/fap/",
    kicker: "CABIN CREW · CIDS · FAP",
    name: "A320 FAP Simulator",
    body: "A full replica of the A320 Flight Attendant Panel: cabin lighting, doors and slides, PRAM announcements, water/waste, lavatory smoke and evacuation signalling.",
    platforms: `v${fap.version} · Android tablet · Windows PC`,
    shot: "lights.png",
    alt: "FAP cabin lighting page",
    width: 1600,
    height: 1000,
  },
  {
    href: "/mcdu/",
    kicker: "PILOTS · MCDU · ND · WXR",
    name: "A320 MCDU Trainer",
    body: "Program the A320 MCDU, follow the flight on the Navigation Display and learn to read the weather radar, then fly the route.",
    platforms: `v${mcdu.version} · Android tablet or phone · Windows PC`,
    shot: "mcdu-dual.png",
    alt: "MCDU and Navigation Display with weather radar",
    width: 1280,
    height: 800,
  },
];

export default function Home() {
  return (
    <div className="radar">
      <SiteHeader />
      <main>
        <section className="mx-auto max-w-6xl px-4 pt-10 pb-14 text-center sm:px-8 lg:pt-16">
          <div className="flex justify-center">
            <Logo size={110} glow />
          </div>
          <p className="mt-8 font-mono text-xs font-bold tracking-[0.3em] text-cyan">
            OVERDRIVE INTERACTIVE
          </p>
          <h1 className="mt-3 text-4xl leading-[1.1] font-extrabold sm:text-5xl">
            A320 training apps
          </h1>
          <p className="mx-auto mt-5 max-w-2xl text-lg leading-relaxed text-silver">
            Classroom trainers for aviation students: practise on realistic A320
            panels on a tablet, at school or at home.
          </p>
        </section>

        <section className="mx-auto grid max-w-6xl gap-6 px-4 pb-20 sm:px-8 lg:grid-cols-2">
          {apps.map((a) => (
            <a
              key={a.href}
              href={asset(a.href)}
              className="group flex flex-col rounded-3xl border border-line bg-panel/70 p-5 transition hover:border-cyan/60 hover:bg-panel sm:p-6"
            >
              <ScreenFrame src={a.shot} alt={a.alt} width={a.width} height={a.height} />
              <p className="mt-6 font-mono text-xs font-bold tracking-[0.3em] text-cyan">
                {a.kicker}
              </p>
              <h2 className="mt-2 text-2xl font-extrabold">{a.name}</h2>
              <p className="mt-3 flex-1 leading-relaxed text-silver">{a.body}</p>
              <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
                <span className="text-xs text-silver/70">{a.platforms}</span>
                <span className="rounded-xl bg-cyan px-5 py-3 text-sm font-extrabold tracking-wider text-black group-hover:brightness-110">
                  OPEN · DOWNLOAD →
                </span>
              </div>
            </a>
          ))}
        </section>
      </main>
      <SiteFooter>
        &quot;A320&quot; and related aircraft trademarks belong to Airbus.
        Overdrive Interactive is independent and not affiliated with or endorsed
        by Airbus.
      </SiteFooter>
    </div>
  );
}
