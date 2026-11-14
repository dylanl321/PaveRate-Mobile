# PaveRate iOS UI review

Reviewed for a foreman in full sun, with gloves, on a phone that stays in the truck or on the paver. No account, no sync. The screens covered are Today, the calculators (including milling), the map, job setup, saved days, settings, empty states, the Home Screen widget, the Lock Screen Live Activity and Dynamic Island, and the watch app and complication.

This pass did not add features, change the math, or touch signing. iOS and watchOS cannot be compiled on Linux, so the SwiftUI changes were checked by reading the iOS 17 / watchOS 10 APIs they use. `swift test` covers `PaveRateCore` only.

## Verified TestFlight bugs

**Lock Screen white on white.** Commit `7133787` fixed the reported bug. Before it, the Live Activity tinted the system card white and left the big numbers on the default label color, which is white. The card is now an opaque near-black board (`BoardInk`): yellow feet, white tons and job name, and bright go / watch / hold colors. Dynamic Island text is the same ink on the system black island, which already had contrast. This pass keeps that board and fills the whole Live Activity card with `containerBackground`, because on iOS 17 a plain `.background` does not always paint the full Lock Screen card.

**Map "End at" keypad.** The decimal pad has no return key. Done lived on `fieldKeyboardDone()`, and the map screen never called it. The field also sits in the bottom sheet, so the keypad covered the number and the Set end button. Every numeric field is a `BigNumberField`. After this pass, each screen that contains one calls `fieldKeyboardDone()`, and dragging the scroll view also dismisses the keypad.

| Screen | Fields | Dismiss |
| --- | --- | --- |
| Today | Day note, photo caption (text keypad) | Done on the keypad, return on a text field, drag to dismiss |
| Load ticket | Truck, tons, feet | Done, and Close |
| Calculators, including milling | Every number | Done, drag to dismiss |
| Map | End at | Done, Set end, drag to dismiss. The map shrinks so the field stays above the keypad |
| GDOT route search | Route name | Done, and Close |
| Job | Width, thickness, truck, air, rain, job name | Done, drag to dismiss |
| Settings | Names and the five numbers | Done, drag to dismiss |

## P0 — unusable

### Night mode chrome disappears

- **Screen:** Every tab, and the Back / Undo / Share / Clear buttons.
- **Problem:** The app tint was `accentText`. In Night that color is the same navy as the background, so the selected tab and the navigation buttons were painted on the dark bar in the dark bar's color.
- **Fix:** Tint with `palette.text` (black in Sunlight and Glare, near-white in Night). The map's location button keeps a blue glyph so it stays visible on the white map control.

### Map station tags were white on white

- **Screen:** Map, Night.
- **Problem:** Station capsules used the default label color on a white fill. In Night the label is white.
- **Fix:** Station tags are black on white with a black stroke. Milepost tags stay white on blue, also stroked, so they read on the satellite photo. Plan and paved lines have a black casing under a white or green stroke so they show on both asphalt and concrete.

### Map end field had no way out

- **Screen:** Map, End at.
- **Problem:** No Done button, and the keypad covered the field and Set end. On an iPhone SE the bottom sheet already used most of the screen.
- **Fix:** Done on the keypad, drag-to-dismiss, and Set end closes the keypad. While the field is focused the map collapses to a strip, the big length hides, and the field sits at the top of the sheet. The map keeps at least 180 points when the keypad is down, and the title is inline so an SE still shows the road.

## P1 — confusing or hard to use with gloves

### Status words failed contrast

- **Screen:** Result chips, weather banners, threat hours, tack and paving warnings. Worst in Night.
- **Problem:** Those fills always used white type. Night's green, amber, and red are light, so the word was about 2.5:1. Sunlight's amber was just under 4.5:1 for the smaller line.
- **Fix:** Each palette has ink for a status fill: white on the dark Sunlight and Glare fills, black on the light Night fills. Sunlight amber is darker so the white word clears the body-text ratio. Remove and Clear use the same red as type on the page, not as a fill, so that red was left light enough to read in Night.

### Glove targets and system pickers

- **Screen:** Job screen picker, Settings length picker, Map Plan / Paved, Edit / Remove load, Remove photo, settings and job toggles.
- **Problem:** Segmented controls stay about 32 points tall. Load and photo actions were a line of type at 44 points, not the full row. Toggles on Settings were a bare switch.
- **Fix:** Sunlight / Glare / Night, Feet / Stations, and Plan / Paved are full-width segments at least 56 points tall. Edit, Remove, and the toggles use the same bordered row as the other field controls. Primary buttons already used the outdoor minimum (72 / 88 / 76). Pressed and disabled buttons change opacity.

### Large type clipped the number

- **Screen:** Today, Map, every calculator result, weather hours, waste percent.
- **Problem:** Heroes were one line with a floor of 40% scale, so a long foot count turned into an ellipsis at accessibility sizes. Weather hours were locked at 116 points. The three waste choices sat in one row. The day note was a single line whose placeholder said "Name".
- **Fix:** Heroes wrap to two lines and can scale further before they truncate. Hour cards grow with the type. Waste stacks vertically at accessibility sizes. Notes and captions grow up to six lines. The typed number stays at the outdoor size, capped at 1.6× so the unit cannot crush it. The field's VoiceOver label includes the unit.

### Labels a foreman had to decode

- **Screen:** Today glare button, Settings, Map, milling.
- **Problem:** In Night the button still said "Glare mode" and jumped to Glare with no hint that Night lives on the Job tab. Settings explained App Groups, bundle ids, and the README. Map said "Route" and "Use this length". Milling's unit was `t/CY`.
- **Fix:** The shortcut says "Use glare" or "Use sunlight" and points Night at the Job tab. Settings says the Lock Screen updates from the app and the widget says "Open PaveRate" until the shared group is in the install. Map says "Find route" and "Use this length in calculators". Milling says `tons/CY`.

### Lock Screen widget and watch glance

- **Screen:** Home Screen widget's Lock Screen families, watch app, complication.
- **Problem:** `7133787` painted the accessory widget yellow. Accessory widgets sit on the wallpaper, not on the dark board, so yellow repeats the white-on-white failure. The watch glance used the system color, so Go and Hold did not read as a status, and "Open iPhone" does not fit a circular complication.
- **Fix:** Lock Screen accessory text uses the system primary color and the widget accent. The Home Screen widget and the Live Activity stay on the dark board. The watch app is a black board with the same go / watch / hold colors as the phone, and the type can shrink instead of clipping. The circular complication says "Open" when nothing has been sent, and still speaks "Open iPhone" to VoiceOver. Complication colors are left to the watch face so a light face does not get forced white type.

### Calculator bar at large type

- **Screen:** Spread rate, feet left, and the other calculators.
- **Problem:** Undo, Share, and Clear were forced to title size, so at accessibility sizes they collided in the bar.
- **Fix:** They use the bar's own type. They stay in the bar so Share and Clear remain one tap. Their hit target is the system 44 points, which is the minimum, not a glove-sized row.

## P2 — polish, and what was left

Fixed while already in the file:

- Copy says "Copied" for two seconds, then returns to "Copy text".
- Clear line and Delete saved day use the red outline, and they still ask first.
- Snap tons uses the same primary button as the other actions, and Undo can put the tons back.
- Empty "show your work" formulas wrap instead of clipping.
- Map progress and the end slider announce feet to VoiceOver. The crosshair is hidden from VoiceOver. Drop point is the control.
- The end field follows the slider until you tap into it, so it is not a blank box next to a length you already set.

Left alone:

- Today is a long scroll: weather, the run, loads, photos, then share. Each block is a real step in the shift. Collapsing it would hide the work.
- The job strip repeats on Today and on every calculator. It is the width, lift, and rate reminder, so it stays.
- The end slider's thumb is still the system thumb. The number field is the control that meets the glove size.
- Share, Clear, and Undo stay in the navigation bar. A second copy at the bottom would be clutter.
- There is no coach-mark tour. The empty states already say what to do next: draw the run on Map, add a load, pull weather, or type the air temperature on Job.
- The widget and Live Activity do not follow Sunlight, Glare, or Night. They stay on the dark board so a light Lock Screen cannot turn the type white on white again.
- Glare sets muted type to black on purpose. Secondary lines do not look lighter than the rest, which is the full-sun rule.
- Station tags on the map stay caption size. Larger tags would cover the road.
- Appearance has two doors: the Today shortcut for glare, and the Job control for Sunlight, Glare, and Night. The shortcut is one tap in the sun.

## What changed

Theme ink, the shared field controls, and the screens listed above. The Lock Screen Live Activity keeps the dark board from `7133787` and now paints that board with `containerBackground`. No formula, stored model, or signing setting changed.
