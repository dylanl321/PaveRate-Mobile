# PaveRate

Offline field calculator for asphalt paving foremen. SwiftUI, iOS 17 and later. No account, no network, no backend.

The math is a port of the public calculators in [dylanl321/paving-calculator](https://github.com/dylanl321/paving-calculator) (`feat/auth-and-data`). Formulas, units, and GDOT Table 12 tolerances follow that app's `src/lib/config/formulas.ts`, `src/lib/config/index.ts`, and `src/lib/config/paverate.yaml`. The asphalt subset of that config lives in [`Config/paverate-asphalt.yaml`](Config/paverate-asphalt.yaml). Swift constants are locked to the file by `ConfigParityTests`.

Soil, concrete, and grading tools are not in this version.

## What you can calculate

Shared job setup (width, compacted thickness, course type, machine, first pass, truck size, tack application, waste, optional air temperature and rain) feeds every screen.

- **Spread rate** — target is thickness × 110 lbs/SY. Actual is tons over the area, minus paver (14 tons), shuttle, or MTV (24 tons) retention on the first pass. Table 12 judges the result: inside the tolerance is in spec, inside 1.5× is marginal, past that is out of spec.
- **Feet left today** — `(ordered − placed) × 2000 × 9 ÷ (width × rate)`, plus how far one truck goes at the job's load size.
- **Distance planner** — how far silo tons plus inbound trucks will reach, and the tons needed for a desired distance.
- **Tonnage to order** — area × rate, plus 0, 5, or 10 percent waste.
- **Tack rate** — gallons at the field-card min, mid, and max for leveling, topping, OGI, or rock chip. Blocked when the air is under 40°F, the rain forecast is at least 0.10 in, or the surface is marked wet.
- **Stick check** — loose height behind the screed is compacted thickness × 1.25.
- **Paving window** — GDOT Table 4 minimum air temperature for the lift, plus the 60°F OGFC/PEM floor.

Each screen shows one large result and an expandable **Show your work** breakdown. The last job and the last inputs are stored on the device.

Sunlight mode is the default: white background, black type, heavy borders, large fields. Night mode uses the web app's dark palette.

## Project layout

- `Sources/PaveRateCore` — pure calculation module
- `Tests/PaveRateCoreTests` — ports of the web formula and spec-check tests
- `App/PaveRate` — SwiftUI app
- `PaveRate.xcodeproj` — iOS app target linked to the local package

## Verify the math

```bash
swift test
```

That builds `PaveRateCore` and runs the unit tests. It does not compile the iOS app.

## Open the app

Open `PaveRate.xcodeproj` in Xcode 15 or later, pick your team under Signing & Capabilities, and run on an iOS 17+ simulator or device. The bundle id is `com.paverate.ios`.

This repository was built on Linux, which cannot compile or launch an iOS target. The app target has not been built here.

## TestFlight

The project ships an app icon (`App/PaveRate/Assets.xcassets`), declares no non-exempt encryption, and is at version 1.0 build 2.

1. Create the app record in App Store Connect with bundle id `com.paverate.ios` (or change the id in the project if it is taken).
2. On a Mac with Xcode signed in to your developer account, run:

   ```bash
   TEAM_ID=YOURTEAMID scripts/testflight.sh
   ```

   Add `BUMP=1` to raise the build number before archiving. To use an App Store Connect API key instead of the Xcode login, also set `ASC_KEY_PATH`, `ASC_KEY_ID`, and `ASC_ISSUER_ID`.
3. Have a foreman check spread rate, feet left, and tack against a known ticket before relying on it in the field.

## Formula notes

These are differences and ambiguities found in the web app while porting. The Swift code follows the running TypeScript and YAML, not the older markdown where they disagree.

- **Stick factor.** `docs/FORMULAS.md` says loose height is compacted × 1.2. `paverate.yaml` and the unit tests use **1.25**. This app uses 1.25.
- **Table 4 gaps.** The lookup uses `thickness <= maxThicknessIn` on rows 1, 2, 3, 4, and 8 inches. A 1.05 in lift therefore uses the 45°F row, even though the written table jumps from "1 in or less" to "1.1 to 2 in." Lifts over 8 in stay on the 32°F row.
- **Misnamed web tests.** `placementCheck(48, 2)` is named as a warning in the web suite, but 48°F is at or above the 45°F minimum, so the function returns pass. `tackTempCheck(40)` is named as a pass, and the assertion expects a warning because 40°F is inside the 5°F margin. This app matches the assertions.
- **Rain thresholds.** The comment at the top of `checks.test.ts` mentions 0.10 in warn and 0.25 in block. The YAML and the assertions use **0.01 in warn** and **0.10 in block**.
- **OGFC / PEM floor.** The paving-window screen compares the course id to the literals `"ogfc"` and `"pem"`. Job setup stores `TOLERANCE.OGFC` and `TOLERANCE.PEM`, so that check never runs on the web. This app applies the 60°F floor to both the literals and the Table 12 ids. The MTV exception (55°F when the engineer approves it) is noted in Show your work and is not a separate pass/fail path, because the web calculator does not implement it.
- **First-pass show-your-work.** The web spread-rate proof multiplies the gross tons by 2000, then prints the rate that already had retention removed. The steps here subtract retention before converting to pounds, so the division matches the rate.
- **Tack rate text.** The web proof prints tack rates with two decimals, which rounds 0.085 gal/SY to 0.09. The gallons still use the full rate. Show your work here prints three decimals so the printed rate is the rate that was multiplied.
- **Zero tons or distance** on spread rate is treated as "not entered," because the web card uses JavaScript truthiness. Zero ordered and zero placed on feet left is a real result of 0 ft.
