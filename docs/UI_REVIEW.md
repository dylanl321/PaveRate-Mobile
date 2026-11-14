# PaveRate iOS UI review

Reviewed for a foreman in full sun, with gloves, on a phone that stays in the truck or on the paver. No account, no sync. The screens covered are Today, the calculators (including milling), the map, job setup, saved days, settings, empty states, the Home Screen widget, the Lock Screen Live Activity and Dynamic Island, and the watch app and complication.

This pass did not add features, change the math, or touch signing. iOS and watchOS cannot be compiled on Linux, so the SwiftUI changes were checked by reading the iOS 17 / watchOS 10 APIs they use. `swift test` covers `PaveRateCore` only.

## Verified TestFlight bugs

**Lock Screen white on white.** Commit `7133787` fixed the reported bug. Before it, the Live Activity tinted the system card white and left the big numbers on the default label color, which is white. The card is now an opaque near-black board (`BoardInk`): yellow feet, white tons and job name, and bright go / watch / hold colors. Dynamic Island text is the same ink on the system black island, which already had contrast. This pass keeps that board and fills the whole Live Activity card with `containerBackground`, because on iOS 17 a plain `.background` does not always paint the full Lock Screen card.

**Map "End at" keypad.** The decimal pad has no return key. There is one Done button. It writes the number back into the field, and on the map it places the end. Dragging the scroll view, or a tap outside the field, closes the keypad without placing the end. While End at is focused the map shrinks so the field stays above the keypad.

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

### Calculator actions

- **Screen:** Spread rate, feet left, and the other calculators.
- **Problem:** Undo, Share, and Clear sat in the navigation bar. At large type they collided, and the bar's hit target stays 44 points.
- **Fix:** Those actions are full-width buttons under the result. Field mode draws them at the glove height. Compact mode draws them at 44 points. One place, no second copy in the bar.

## Layout density

Settings, and the first launch of this build, ask for **Field** or **Compact**. The choice is stored with `@AppStorage` (`paverate.layoutDensity`) and applied in `FieldPalette.palette(for:density:)`. Every screen reads button height, page padding, stack spacing, corner radius, type size, keypad height, slider row, and map-tag size from that palette. There is no per-screen branch. Field is the default. Compact uses the same Sunlight, Glare, and Night colors, including the status ink. Glare in Compact keeps the heavy border and the black type, with standard control heights.

## P2

- Copy returns to "Copy text" after two seconds.
- Clear line and Delete saved day use the red outline and still ask first.
- Snap tons uses the primary button, and Undo can put the tons back.
- Show-your-work formulas wrap.
- Map progress and the end slider announce feet. The crosshair is hidden from VoiceOver. Drop point is the control.
- The end field follows the slider until you type in it. Done commits that number and places the end.
- Today stays one scroll, because each block is a step in the shift. Compact spacing fits more of it on the screen. The job strip stays, and it uses the same padding token so Compact makes it shorter.
- The end slider row uses the layout height. Field gives it a taller hit area. Compact keeps 44 points.
- Share, Clear, and Undo are the content buttons above, not a second row in the bar.
- First launch is the density choice, not a coach-mark tour. Empty states still say the next step: draw the run, add a load, pull weather, or type the air temperature.
- The widget and Live Activity stay on the dark board in both modes so a light Lock Screen cannot turn the type white on white.
- Glare keeps black secondary type. That is the full-sun rule, in Field and in Compact.
- Map station tags use the layout's tag size, larger in Field and smaller in Compact so they do not cover the road.
- Sunlight, Glare, and Night stay on the Job tab, with the Today glare shortcut. Density is the separate control.

## What changed

Theme ink, the shared field controls, the density token, and the screens listed above. The Lock Screen keeps the dark board from `7133787`. One keypad Done button commits the number and, on the map, places the end. Build number is 6. No formula or signing setting changed.
