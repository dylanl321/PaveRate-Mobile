# PaveRate field app — product plan

This is the plan for the iOS app a paving foreman actually keeps in a vest pocket. v1 (PR #1) is the offline calculator: shared job setup, spread rate with GDOT Table 12, feet left, distance planner, tonnage, tack, stick check, and the Table 4 paving window. The math is the asphalt port of [dylanl321/paving-calculator](https://github.com/dylanl321/paving-calculator) `feat/auth-and-data`.

v2, the work in this branch, is the phone becoming useful before the first truck is ticketed and still useful when the signal drops behind a bridge. v3 is the same phone talking to the web app's projects and accounts.

The person holding it is wearing gloves, squinting, and has one hand free. The other hand is on a rake, a ticket, or the paver. Decisions are go / wait / stop, and they get texted to a superintendent who is not on the job.

## The day, from the shoulder

### Before anyone is on the clock

The foreman looks at the phone in the truck, often still in the dark. Three questions:

1. Can we pave this lift today? Table 4 minimum air temperature for the thickness, the 60°F floor for OGFC and PEM, and "32°F and rising, base not frozen" on thick lifts.
2. Can we tack? Air at least 40°F in the shade, surface dry, and no rain that will land on fresh tack. The web app warns at 0.01 in over the next 24 hours and blocks at 0.10 in. Those are the numbers this app uses.
3. How many tons do I tell the plant, and how many trucks is that at our load size?

If the answer to 1 or 2 is no, the valuable action is a text, not a calculation. "Holding SR 20. 38° and 0.20 in on the way. Don't send trucks." That text has to be honest about whether the weather was read on the mat or saved from last night.

The length for the tonnage call is rarely a number they remember. It is a stretch of road: from the driveway at the church to the joint they cut yesterday. They need to see that stretch and see the feet.

### Laydown

Tack goes out ahead of the paver. Gallons come from the length, the width, and the field-card rate (leveling, topping, OGI, rock chip). The mid rate is the number they shoot. The range is what they defend.

The first loads are a lie on spread rate if nobody subtracts the paver (14 tons) or the shuttle / MTV (24 tons). v1 already does that on the first pass. The foreman still needs the tons from the ticket in the running total, because the next question is "how far is left and do I have enough mix to get there."

A screed check is a separate glance: loose height is compacted thickness times 1.25. It happens once when the paver is set, then again if the mat looks wrong.

### Mid-shift

This is where jobs go out of spec. The paver speeds up, the depth drifts, a truck is light, the wind comes up and the mat cools, or a shower is two hours out and the joint is not in.

The check that matters is per load, not at the end of the day: these tons, this many feet, this width, against the target rate and Table 12. Inside the tolerance is in spec. Inside 1.5 times the tolerance is marginal. Past that, stop and fix the head before the next truck.

The other mid-shift check is the rain timeline. A daily total of 0.08 in can be "all of it at 2 PM" or "a trace all day." The foreman needs the hours, so they can shoot tack in the dry gap or get the joint in first.

Wind is not a GDOT cutoff in the spec this app carries. It is still why tack misses the lane and why a thin lift crusts. The app says so as a field note, in different words from a Table 4 failure, so nobody quotes it as a spec.

### End of the day

The superintendent wants, in one place: where we stopped, tons placed against tons ordered, whether yield held, what the weather did, and anything that was out of spec. Today that is a phone call and a paper ticket book. The useful object is a short note the foreman can text or email without retyping, plus the tickets that add up to the tons-placed number.

The stopping point should still be on the map in the morning. Multi-day jobs are normal. "New day" clears today's tons and the paved track. It does not forget the planned run, the width, or the mix.

## What v1 already gets right

Keep these. They are the reason the app is trustworthy.

- One job setup feeds every calculator. Width, thickness, course, machine, first pass, truck size, tack, waste.
- One big result, then "Show your work" with the same steps as the web app.
- Sunlight colors: white card, black type, heavy border, safety yellow. Night colors from the web theme.
- Last job restored on this phone. No account required to do the math.
- Table 12 and Table 4 and the tack block rules match the running web config, including the places the web's own comments disagree with the YAML. See the v1 README formula notes. v2 does not reopen those.

## Ranked work

Value is "does a foreman change a decision or avoid a phone call." Effort is app scope, not a calendar.

| Rank | Idea | Value | Effort | When |
| --- | --- | --- | --- | --- |
| 1 | GPS weather into the temp and rain checks, with a saved reading when the radio dies | Stops a bad start and a bad tack shot | Medium | v2, in this branch |
| 2 | Map the run, show feet and square yards, pour that length into the calculators | The tonnage call and feet-left stop being guesses | Medium | v2, in this branch |
| 3 | Load tickets: running tons, expected feet, yield against Table 12 | This is the mid-shift job | Medium | v2, in this branch |
| 4 | Share a day note as text, picture, and PDF | Replaces the end-of-day retype | Low | v2, in this branch |
| 5 | Glove, glare, one-thumb pass | The rest does not matter if they fat-finger it | Medium | v2, in this branch |
| 6 | Feet-left and tons-remaining on the Lock Screen (Live Activity, then a widget) | The number stays visible while the phone is face-up on the paver | Medium, separate extension | Next, after a device check |
| 7 | Photo on a station ("joint at 12+40, segregated") | The daily report already asks for it | Low once photos exist | Next |
| 8 | GDOT centerline and real mileposts from the web app's route service | Ties the drawing to the plans | Medium, needs the web session | v2 draws a public GDOT search; real LRS mileposts wait on v3 |
| 9 | Offline-first sync of the job, the run, and the day's tickets to web projects | Office and field stop keeping two books | High | v3 |
| 10 | Watch complication for "OK / hold" and feet left | Glance while raking | Medium | After the phone habits are real |

Not ranked as product, because they are guesses until Dylan says otherwise: voice entry on a screaming paver, a Bluetooth infrared gun, metric units, soil and concrete calculators.

## Weather

### What the foreman sees

A full-width call at the top of Today and on the paving window. One of: **OK to pave**, **Borderline — watch it**, **Too cold to pave**, **Too cold to tack**, **Too cold for OGFC/PEM**, **Hold — rain in the next 24 h**. Color matches the v1 banners (green, amber, red). Under it, in type large enough to read at arm's length: air °F, wind mph and compass, rain inches next 24 h, and the ground forecast.

The next eight hours are a sideways row of big cards: hour, temperature, rain amount. A dry gap is visible without doing math. Hours that fail the web's rain threat rule (any rain, probability at least 40%, or a rain weather code) are marked.

A line of small type tells the truth about the reading: "Apple Weather, 4 min ago" or "Open-Meteo, 2 h ago" or "Saved on this phone." If the phone has moved more than 15 miles from where the reading was taken, the strip says so and does not quietly fill the job.

### How a reading becomes a decision

The same functions v1 already uses, fed by the reading instead of by typing:

- Air temperature goes into `placementCheck` (Table 4 for this lift) and `tackTempCheck` (40°F, with the 5°F warning the web treats as a warning exactly at 40).
- OGFC and PEM still use the 60°F floor, including the Table 12 ids the web setup screen stores. The MTV 55°F exception stays a note, not a separate pass, same as v1.
- The next 24 hours of precipitation, in inches, goes into `rainCheck`. Warn at 0.01. Block at 0.10.
- Raining now, or a snow code, offers a wet surface. Tack stays blocked while the surface is wet. The app will set wet. It will not clear wet. Puddles outlast a radar pixel. Clearing it is a thumb on the Job tab.
- Ground temperature is the Open-Meteo soil temperature at 0 cm. It is not an infrared reading of the mat. If that forecast is below 32°F, the strip says the Table 4 note about a frozen base, and it says what the number is. An IR gun is still how you know the mat.
- Wind at 15 mph or more is a field note in amber, including at 25 mph. It does not block tack and it does not use a GDOT clause. The copy says "field note, not a GDOT cutoff." The thresholds are his to change. See open questions.

### Sources and the dead-radio case

Preferred source is Apple WeatherKit (current conditions plus the hourly forecast). It needs the WeatherKit capability on the App ID. Setup is in the README.

If WeatherKit is missing, not entitled, or the call fails, the app calls Open-Meteo with no key. That is the same service the web app uses (`https://api.open-meteo.com/v1/forecast` and the geocoding host in `paverate.yaml`). Temperature in °F, wind in mph, precipitation in millimeters converted with 1/25.4 the way `src/lib/services/weather.ts` does it. The 24-hour rain sum skips hours outside the window, same as the web.

When both answer, WeatherKit supplies air, wind, the rain total, and the hours. Open-Meteo fills ground temperature, which WeatherKit does not have.

The last reading is stored on the phone with the time and the coordinate. The web app refreshes every 30 minutes. This app uses the same window:

- Under 30 minutes: fresh. Follow-along may fill empty or unlocked temperature and rain fields.
- 30 minutes to 6 hours: old but still shown, and follow-along may still use it. A bridge can eat the signal for a while.
- Past 6 hours: shown, labeled old, not applied by itself.

"Use GPS weather" always pulls a new reading for where the phone is and fills the job. "Use saved reading" fills from the phone even when the reading is old or was taken somewhere else, and then leaves the numbers alone until the next deliberate pull. Typing a temperature or a rain amount on the Job tab also locks that field, so a refresh does not stomp a number off a truck thermometer.

Nothing about a failed fetch deletes the saved reading. The calculators keep working with whatever is in the job.

## The map

### What the foreman sees

A hybrid map, a crosshair in the middle, and a bottom sheet the thumb can reach.

The bottom sheet leads with the length in feet and the station (12+40 means 1,240 ft from the start of the line they drew). Under that: square yards at the job width, paved feet, feet left along the plan, and a bar. If the paved line is more than 5% longer than the plan, the sheet says the track is longer than the plan, which is either GPS wander or they passed the end. It does not silently "fix" the number.

Two lines:

- **Plan.** Black. The work they meant to do. Pan the crosshair to the start, tap **Drop point**, pan to the next bend, drop again. A tap on the map drops a point there too, for a bare hand.
- **Paved.** Green. What they have covered. Same drop gesture, or **Track**, which records GPS while the app is open. Points worse than 30 m of accuracy are ignored. Points closer than 10 ft to the last one are ignored, so a parked truck does not grow the line. The track stops at 5,000 points rather than filling the phone.

Green also paints along the plan for the paved distance, with a marker at the head. That is "today versus the segment," even when the truck's GPS is a lane off the line they drew. The length used for tonnage is the plan if they drew one, otherwise the track.

**Use this length** writes that footage into tonnage, tack, spread-rate distance, and the feet-left total. One tap. Each of those screens also has its own button if they only want it in one place.

### GDOT

A **Route** sheet searches the public GDOT GPAS map service, the same layer the web app's legacy route search uses (`GDOT/GDOT_GPAS` MapServer layer 5, route id and road name, geometry in WGS84). Results are big rows with the county, because "SR 20" is a lot of counties. Picking one draws the centerline and shows its length. It does not pour that length into the calculators. A full route is often many miles, and a wrong tonnage order is expensive. There is a separate button that copies the centerline length, with the number printed on it.

That centerline is not an official milepost. The web app's `/api/gdot-routes` bbox path reads `dot_road_segments` out of D1 and is the right source for a local LRS overlay once the phone is signed in. v2 does not pretend station 0 of a search result is the county milepost. v3 should use the web route, with the measure the plans actually use. Which measure is an open question.

The drawn run is stored on the phone. The centerline is stored too, so it is still there with no signal.

## Tickets and yield

Today has a load list. Add truck, tons, and optional feet this load covered. The row shows:

- Running tons, which is what Feet Left uses as "tons placed" while any loads exist. The typed tons-placed box comes back if the list is empty.
- How far that load should reach at the job width and the target rate (thickness times 110).
- If they entered feet, the actual rate and the Table 12 call. Hopper retention stays on the spread-rate tool's first pass. It is not subtracted again on every truck. A per-load yield that subtracts 14 tons would call every truck light.

**New day** asks first, then clears loads, the paved track, and today's ticket inputs. The plan, the width, the mix, and the weather stay. Undo puts the day back. There is no archive yet. The share sheet is the record until v3.

## Sharing

One **Share** button builds a plain-text note, a high-contrast picture, and a PDF, and hands all three to the system share sheet. Text is what a crew thread wants. The picture is what stays readable in a message preview. The PDF is what a superintendent files.

**Copy text** puts the same words on the pasteboard for a message they already started.

The note is short enough to read on a phone:

- Job name, width, lift, target rate, course, when it was noted.
- Weather call, air, wind, ground forecast, rain total, how old the reading is and which service it came from.
- Planned and paved feet, stations, area.
- Each load, the running tons, the yield call.
- Feet left, and the spread check if they ran one.

It does not include a login, a token, or a coordinate trail beyond the weather age line.

## Gloves, sun, one hand

v1's sunlight theme is the right idea. v2 pushes it.

- Targets on the default sunlight theme are at least 76 pt. Glare mode goes to 88 pt, black type on white, 4 pt borders, hints in black rather than gray. Glare is one button on Today. Night stays on the Job tab for the cab.
- Type sizes are fixed and large. A system text-size setting that shrinks the result is the failure mode in the sun. Dynamic Type as an optional ceiling is an open question, not the default.
- The primary action sits in the thumb zone: share and weather on Today, drop point / track / use length on the map. The result stays at the top so a phone lying on the paver console can be read without picking it up.
- Steppers stay on width and thickness. Ticket tons do not get steppers. A ticket is an exact number. Map footage does get 10 ft and 50 ft steps for "we're about here" on the paved distance when they are not tracking.
- Haptics on steppers, on a weather call that is not a pass, and on a load that comes back out of spec. The banner is still the source of truth. The buzz is so they notice without staring.
- Undo covers weather apply, new day, deleting a point, deleting a load, and clearing a calculator. Typing still uses the system keyboard undo.
- The last job is still the next job. They do not re-enter width every morning.
- Empty states say what to do in one line ("Drop two points, or track the run") rather than explaining the feature.
- Destructive actions (new day, clear the line) ask. Applying weather does not ask, because Undo is right there and the common case is "yes, use it."

Voice entry is not in v2. A paver is louder than a voice model, and a wrong tons number is worse than typing. Worth a trial later on the weather call only ("hold" / "we're good"), not on ticket entry.

A Live Activity for feet left and tons remaining is the right next interface, and it is not in this branch. It is a second app extension, it needs a device to prove the Lock Screen layout, and the data it would show is already on Today. The Watch is the same idea on a smaller screen, after the phone version has been in a vest for a while.

Units stay US customary. Stations are a display of feet, not a second unit system. GDOT talks in feet, tons, lbs/SY, gallons, and °F.

## What v2 ships in this branch

- Weather pull (WeatherKit, then Open-Meteo), hourly rain, wind, ground forecast, offline cache, fill-in to the existing checks, wet-surface behavior above.
- Map with plan and paved lines, length, station, area, progress, length sent into the calculators, optional GDOT centerline search.
- Load list, running tons, per-load yield.
- Share sheet (text, image, PDF) and copy.
- Glare mode, larger targets, bottom actions, haptics, undo, new day.
- Logic and tests in `PaveRateCore`. The iOS target is not built on the Linux machine that produced this branch. See the README.

## v3 — the web app

The web app already has accounts, orgs, projects, job sites, GDOT segments in D1, document import, and the same formulas. The phone should not grow a second backend.

Sync, when it comes:

- Sign in with the same account. The web app's invite flow is the way a foreman joins a company. The phone stores the session in the keychain.
- Download the project: name, width, thickness, course, route geometry, plans that were imported. The phone still calculates locally.
- Upload the day: loads, the run, the weather reading that was used, the share-note text. The office sees it on the project.
- Offline-first. Writes land in a queue on the phone. A dead spot does not block a ticket. Conflicts are real when two foremen ticket the same job. The sane rule is append-only tickets (a load is an event, not a cell both sides edit) and last-writer-wins on job setup, with the job setup change visible ("width changed to 14 ft from the office").
- Route overlay switches from the public GPAS search to `GET /api/gdot-routes?bbox=` and `?q=`, so the line is the local segment the project already stored.
- Weather can stay on-device. The web weather path is a convenience for the office, not a better instrument than the phone's location.

Do not block v2 on any of that. A foreman can use this branch with no account.

## Open questions for Dylan

1. Wind at 15 mph (note) is a field estimate, not a spec. Keep it, change the number, or drop it so the only weather calls are Table 4, tack temperature, and the rain thresholds?
2. Ground temperature is a forecast soil temperature, labeled as such. Do you want a later pass that records an IR gun reading (typed, or Bluetooth) next to it? The spec cares about the mat and the base, not the model.
3. Snow codes set the surface wet and say so. The web rain check does not treat snow separately. Keep that, or match the web and ignore snow codes?
4. A saved reading is not auto-applied past 6 hours, or if the phone is more than 15 miles from where it was read. Are those the right cutoffs for how your crews move?
5. "New day" throws away the load list after a confirm. Until sync exists, is the share sheet enough of a record, or should the phone keep a stack of past days on the device?
6. Per-load yield ignores hopper retention. Confirm that. Retention stays on the first-pass spread check only.
7. GDOT search draws a centerline and does not treat its start as a milepost. Which measure should v3 show: the LRS milepost on the route, the county mile, or the stationing from the plans?
8. WeatherKit has to be turned on for the App ID or the call fails and Open-Meteo fills in. Is the bundle id staying `com.paverate.ios`, and do you want WeatherKit enabled before TestFlight?
9. Live Activity next: is the phone usually on the paver console (Lock Screen matters) or in a pocket (the Watch matters more)?
10. Voice: worth a trial limited to the weather call, or leave the microphone out of a jobsite app?
11. Any crew that needs meters, or is this imperial for good?
12. Two foremen on one job, both offline, is the conflict that will define v3. Is append-only loads the rule you want?
