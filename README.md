# PaveRate

Field calculator for asphalt paving foremen. SwiftUI, iOS 17 and later. No account required. The math works with no signal. Weather, the run map, and a GDOT centerline search use the network when it is there, and the last weather reading stays on the phone when it is not.

The product plan for the field day, and what is deliberately not in this build, is [docs/PRODUCT_PLAN.md](docs/PRODUCT_PLAN.md).

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

Each screen shows one large result and an expandable **Show your work** breakdown. The last job, the last inputs, the drawn run, the load list, and the last weather reading are stored on the device.

**Today** pulls weather for the phone's location and fills air temperature and the 24-hour rain total. Apple WeatherKit is preferred. If it is not entitled or the call fails, Open-Meteo answers with no key (the same forecast host the web app uses). A saved reading is not applied on its own once it is older than 6 hours, or once the phone is more than 15 miles from where it was read.

**Map** follows the road. Drop a start (or use GPS), pick a direction (both ways of the snapped road), then set the end by tapping the highlighted road, typing a length such as 2400 ft, or dragging the slider. The line is the real centerline: GDOT GPAS when that layer answers, otherwise a short MapKit route. Road name, along-road length, area at the job width, and station ticks stay on screen. Milepost labels appear when the GDOT piece includes begin and end measures. At a fork you pick the turn. If neither road service answers, the map says so and you drop points by hand. That length still feeds the calculators. Route search is the same public GDOT layer and is not applied until you tap the button that prints its length.

**Milling** is length × width × depth: square yards, tons removed, and truckloads. Density defaults to 2 tons per cubic yard and stays on the phone with the other inputs.

**Watch** (`com.paverate.ios.watchkitapp`) shows go, hold, feet left, and tons left. The phone sends that board over Watch Connectivity. The glance complication is `com.paverate.ios.watchkitapp.paveglance`. The watch does not use an App Group.

**Loads** keep a running tonnage and, when you enter the feet a load covered, a Table 12 yield. Feet Left uses that total while the list has tickets.

**Share** sends the day as text, a high-contrast picture, and a PDF. Copy puts the same text on the pasteboard. Photos are pages in the PDF.

**New day** writes the shift to Saved days on the phone before it clears loads, the paved track, photos, and the note. The plan and the mix stay.

**Settings** hold the foreman and crew names, feet or stations as the big length, the wind-note speed, the call-the-plant threshold, default width and mix, Glare as the default, and the Lock Screen switch.

**Lock Screen and widget.** The Live Activity is started by the app through ActivityKit. It does not need an App Group, so feet left, tons left, and the go or hold call still show on the Lock Screen while the phone sits on the paver. The Home Screen widget reads `group.com.paverate.ios` when that group is on the provisioning profile. Until then it shows “Open PaveRate”. The entitlements files do not request the group, so an archive signs without it.

To share the live numbers with the widget later:

1. In the Apple Developer account, register an App Group named `group.com.paverate.ios`.
2. Turn that group on for `com.paverate.ios` and for `com.paverate.ios.widget`.
3. Add this block back to `App/PaveRate/PaveRate.entitlements` and to `Widget/PaveRateWidget.entitlements`:

   ```xml
   <key>com.apple.security.application-groups</key>
   <array>
     <string>group.com.paverate.ios</string>
   </array>
   ```

4. Regenerate the provisioning profiles (Xcode Signing & Capabilities, or download them again) and archive with `scripts/testflight.sh`.

The app already writes the board into that suite when the defaults object exists. The widget already reads it.

Sunlight mode is the default: white background, black type, heavy borders, large fields. Glare mode is the same idea with larger targets for full sun. Night mode uses the web app's dark palette.

## Project layout

- `Sources/PaveRateCore` — pure calculation module
- `Tests/PaveRateCoreTests` — ports of the web formula and spec-check tests
- `App/PaveRate` — SwiftUI app
- `Watch/` — watchOS glance and complication
- `PaveRate.xcodeproj` — iOS app, widget, and watch targets linked to the local package

## Verify the math

```bash
swift test
```

That builds `PaveRateCore` and runs the unit tests. It does not compile the iOS app.

## Open the app

Open `PaveRate.xcodeproj` in Xcode 15 or later, pick your team under Signing & Capabilities, and run on an iOS 17+ simulator or device. The bundle id is `com.paverate.ios`.

The target asks for location when you pull weather or track a run (`NSLocationWhenInUseUsageDescription`). It does not ask for always-on location.

### WeatherKit

`App/PaveRate/PaveRate.entitlements` includes the WeatherKit entitlement, and the target points at that file. WeatherKit still has to be turned on for the App ID or the signed build will not install:

1. In the Apple Developer account, open the identifier for `com.paverate.ios` (or whatever bundle id you sign with).
2. Enable the WeatherKit capability and save.
3. In Xcode, Signing & Capabilities should show WeatherKit. If the capability was added by hand, regenerate the provisioning profile.
4. If a simulator refuses to install because the profile does not include WeatherKit, delete the `com.apple.developer.weatherkit` key from the entitlements file until the capability exists. Open-Meteo still fills temperature, wind, rain, the hourly timeline, and the ground forecast.

WeatherKit does not return a ground temperature. When both services answer, the air, wind, and rain come from WeatherKit and the ground forecast comes from Open-Meteo. The ground number is a soil forecast, not an infrared reading of the mat.

This repository was built on Linux, which cannot compile or launch an iOS target. `swift test` covers the package. The app target has not been built here. Map, location permission, WeatherKit, and the share sheet need a simulator or a device.

## TestFlight

The project ships an app icon (`App/PaveRate/Assets.xcassets`), declares no non-exempt encryption, and is at version 1.0 build 5. Builds 2, 3, and 4 are already on TestFlight. Archive the next one with `scripts/testflight.sh`. Do not pass `BUMP=1` unless 5 has already been uploaded.

The map follows the road: start, direction, then an end (a tap on the highlighted road, a length, or the slider). If the road service is down, drop points by hand. Milling is with the other calculators. The Watch app (`com.paverate.ios.watchkitapp`) shows go/hold, feet left, and tons left from the phone over Watch Connectivity. It does not use an App Group. The Home Screen widget still reads `group.com.paverate.ios` only when that group is on the profile; until then it says “Open PaveRate”. There is no account and no web sync.

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
