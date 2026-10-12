# FAP — AISAT Airbus A320 Flight Attendant Panel Simulator

A training replica of the A320 CIDS Flight Attendant Panel, built for
AISAT Aviation College cabin crew trainees.

- **Website (Overdrive Interactive):** https://opulencecircle82.github.io/OI/
  - A320 FAP page: https://opulencecircle82.github.io/OI/fap/
  - A320 MCDU Trainer page: https://opulencecircle82.github.io/OI/mcdu/
  - The old link https://opulencecircle82.github.io/FAP/ redirects to the FAP page.
- **Downloads:** [releases](https://github.com/opulencecircle82/OI/releases), one
  release per app (tags `vX.Y.Z` = FAP, `mcdu-vX.Y` = MCDU Trainer). The site
  links to the exact tag, so update `landing/app/site.ts` on every release.

| Folder | What it is |
| --- | --- |
| `a320_fap/` | Flutter app (Android tablet + web). It runs fully offline. |
| `landing/` | Next.js landing page (static export for GitHub Pages) |
| `Module/` | Original project brief, reference photo and AISAT logo |

## Release a new APK
```bash
cd a320_fap
flutter test
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk AISAT_FAP_vX.Y.apk
gh release create vX.Y.0 AISAT_FAP_vX.Y.apk --title "AISAT FAP vX.Y"
```
The download button and the QR codes always point to the newest release.
When the version number changes, update `apkName` in
`landing/app/site.ts` and `apkFileName` in `a320_fap/lib/config.dart`.

## Update the landing page
```bash
./deploy.sh
```
