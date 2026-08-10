# The Workshop for iOS — Concourse Board

The native app carries the same visual world as the web app. **The normative
token contract lives in the web repo's `DESIGN.md`** (`EnzoLopez2023/workshop`);
this file records only what is specific to the iOS implementation.

## The world

A Solari rail departure board. A shop record reads like a concourse: every
project is a row that flips into its new state, and the board's grid — split
line, cell divider, steel frame — *is* the layout, not decoration. It refuses
the warm-paper / editorial-serif / terracotta arrangement it replaced.

Light is the default rendition (a lit concourse). Dark is the board's own night
form, **not an inversion**: steel *lifts* rather than darkens, and the signal
lamps brighten — which is what a real board does when the hall lights go down.

**The risk this world runs:** it collapses into "one animation on a normal app".
It survives only because the split line, cell grid, steel frame and tracked caps
are structural at rest. The board reads as a board with animation disabled.

## Tokens

`Workshop/App/Palette.swift` is the single source. Every token is a `WSColor`
carrying a light and a dark hex, resolved through a `UIColor` trait callback.
Values are ported verbatim from the web `DESIGN.md` — do not re-derive them.

Flap modules (`flapFace`, `flapFaceLo`, `flapLetter`) are **dark in both
renditions**. They are hardware, not a colour scheme, and this single decision
does more work than any other in the port.

Radii: `rFlap` 2pt, `rPanel` 3pt. **Nothing in the app exceeds 3pt.** The one
exception is the lightbox close button, which is a full-screen photo affordance
matching system Photos.

## Type

No `font-stretch` on Apple platforms, so the condensed board face is baked as
static instances with `fontTools.varLib.instancer` and shipped in `Fonts/`:

| Family | Instance | Used for |
|---|---|---|
| `Martian Mono Board` | wdth 82, wght 400/600/700 | board caps, every datum, every figure |
| `Archivo WS` | wdth 100, wght 400/500/700 | UI labels, body copy, descriptions |

Reach for them via `Theme.board(_:_:relativeTo:)` and `Theme.ui(_:_:relativeTo:)`,
never `Font.custom` directly — the helpers wire up Dynamic Type.

Both families are registered in `project.yml` for the **app and widget targets
separately**. An app extension cannot read its host app's `UIAppFonts`, so the
duplication is deliberate.

Text size is a five-step scale (`TextSize`), applied once at `RootView` as a
Dynamic Type override, so it reaches everything the two helpers hand out. Step 2
is iOS's own default; **step 3 is Workshop's** — a shop screen is read at arm's
length, across a bench, often through safety glasses. Step 5 stops at
`.xxxLarge`; the accessibility sizes above it break the board's fixed-slot rows.
`Theme.boardFixed` is the one escape hatch, for the picker's own samples, where
type that scaled with the setting would defeat the sample.

## The reading column

`contentColumn(_:)` caps content so cards don't stretch into ribbons. A hard cap,
though, turns a landscape iPad into a narrow app between two dead bands — so
where the space is wider than the cap, the column reclaims **a third of the
leftover margin** (`ContentColumnLayout`). Still a column, noticeably less blank.

It's a `Layout`, not a `.frame(maxWidth:)`, because it needs the width actually
*proposed* to the content; a `GeometryReader` would claim the space instead of
measuring it. The trigger is width, not orientation — a vertical `ScrollView`
proposes a `nil` height to its content, so orientation is not knowable from in
there. Where there's no slack (any phone in portrait) it is a no-op.

## The rule about amber

Amber is a signal lamp, not a brand colour. **One amber element per screen**,
and it marks the primary action or the live figure — the `+` on the dashboard,
the print button on the shopping list, the sign-in button, the in-progress flag.

Use `Theme.accentDeep` (#C77800) for system control tints. `Theme.accent`
(#8A4F00) reads *brown* on a tint and is for text-on-light emphasis only.

## Components

| Component | Role |
|---|---|
| `SplitFlap` | Rolls a string into place on one motor with staggered starts, like a real Solari unit |
| `FlapToggleStyle` | Every `Toggle` is a two-cell flap reading OFF/ON. The system capsule has no place here |
| `Flag` / `StatusBadge` | Status as a board flag, not a pill |
| `ProjectCard` / `ShaperProjectCard` | Departure cards: tracked-caps title, status flag, three-cell data strip |
| `BoardCaps` / `Readout` / `Rail` | The board's structural type and rules |
| `BoardToolbarButton` | A flap on the steel band, amber or recessed steel |
| `SignInPlate` | The two providers as one pair of plates: same lettering, same metrics, only fill and mark differ |
| `CutPlanBoard` | Recolours NintekKit cut plans at the app boundary. Sheet and ink stay fixed — a cut plan is a printed document, not a themed surface |

## Where the platform wins

This is an Operate surface, so native expectations outrank expression:

- **The system back button stays native.** Replacing it would cost the
  interactive pop gesture for a cosmetic gain.
- **The iOS 26 floating tab bar stays.** Its contents are board type and signal
  amber; the glass shell is platform chrome.
- **Nav titles are `.inline` everywhere.** Content already carries board headers,
  so a large title was a second, redundant heading.

Two iOS 26 behaviours must be actively opted out of:

1. Toolbar items get a glass capsule. Every `ToolbarItem` therefore takes
   `.boardToolbarItem()`, which applies `sharedBackgroundVisibility(.hidden)`.
2. A `Button` with a custom background and **no explicit `buttonStyle`** is
   dimmed to ~43% in dark mode. Any button that paints its own surface needs
   `.buttonStyle(.plain)`.

## Widgets and the share extension

The widgets carry the same world, mirrored in `WorkshopWidgets/WidgetSupport.swift`
because an app extension cannot reach the app's `Theme`/`Palette`. `WSWidget`
holds the same hexes, `wsAdaptive(light:dark:)` stands in for `WSColor`, and
`WSCaps` / `WSFlap` / `WSFlapNumber` / `WSHeader` are the widget-budget versions
of the app's primitives. Flaps are **static** here — a widget gets no animation
budget, and the board has to read as a board at rest anyway.

Rules that came out of building them:

- **The board bleeds to the edges.** `.contentMarginsDisabled()` plus
  `containerBackground(WSWidget.flap)`, so the steel header band touches the
  widget's own rounded corners. Without it the board floats inside ~22pt of
  system padding and reads as a card, not a board.
- **A board always shows a fixed number of slots.** Unfilled rows stay blank
  shaded board with their hairline separators intact, the way a departure board
  reads between arrivals. Never collapse the list and leave bright flap face
  below it — that reads as a truncated card. Filled rows sit on `flap`, the
  container is `flapShade`.
- **Rows divide the height evenly** (`.frame(maxHeight: .infinity)`), so no size
  class ends up with dead space.
- **One amber per widget.** The header's trailing figure or the single headline
  stat. Green and red stay reserved for status; money is neutral flap type, not
  green.
- **Each extension bundles its own fonts.** `UIAppFonts` does not cross the
  app/extension boundary. The widgets carry all six faces (~532KB); the share
  extension carries only the two it uses (~170KB).

The share extension answers with a board confirmation card rather than a system
alert — steel band, hammer lamp, `SAVED` / `NOT SAVED`, auto-dismissing. It is
the only place the world appears outside the app, so it has to be unmistakable.

Widgets cannot be placed on the Home Screen from `simctl` (no tap command, no
`idb`). They were verified by temporarily compiling the widget views into the
app target and rendering them at real pixel sizes; that harness was reverted
after the pass.

## The iPad / Mac sidebar

The sidebar is the steel frame the board hangs on — the same face as the
toolbar, so the two meet as one continuous edge instead of a light column
butting into a dark bar. Destinations are board caps; the active one is lit
with an amber lamp bar on its leading edge and a lifted `steelLight` plate.
The header reuses the sign-in plate's lockup verbatim (amber `hammer.fill` +
`THE WORKSHOP`), so the app announces itself the same way everywhere.

A system `.sidebar` `List` cannot carry this — its background, row type and
selection capsule are all platform chrome, and `.tint()` only recolours the
capsule. It is a plain stack of buttons instead. The split view, its collapse
toggle (which lives in the *detail* column's toolbar) and the swipe gesture
all stay native.

When it slides in over the board rather than beside it, the rail is **frosted
steel** — `Theme.steel` at 0.8 over `.ultraThinMaterial`, header band at 0.9 —
so the rows behind it stay faintly there. Opaque steel reads as a second screen
having replaced the first.

**A `Rectangle` with only a width set has unbounded height** and will stretch
its row to the full column. The lamp bar rides in an `.overlay(alignment:
.leading)`, which never affects layout.

## Photos

`AuthImage` uses `.fill`, which means it reports a size **larger** than the
proposal on one axis. Never hand it an aspect ratio directly:

```swift
// WRONG — the photo draws outside its layout box and spills across the grid.
AuthImage(url: url, contentMode: .fill)
    .aspectRatio(16.0 / 10.0, contentMode: .fill)
    .clipped()
```

Bound the box first, then fill it:

```swift
Rectangle().fill(Theme.flapShade)
    .aspectRatio(16.0 / 10.0, contentMode: .fit)   // the box
    .overlay { AuthImage(url: url, contentMode: .fill) }
    .clipped()
```

An explicit `.frame(width:height:)` or `.frame(height:)` before `.clipped()`
works too. Every call site uses one of these two forms.

## Shipping to the App Store

Three things here exist only because App Review or the upload validator demands
them, and all three are easy to undo by accident.

**Every binary carries a `PrivacyInfo.xcprivacy`** — the app, the widget and the
share extension. All three statically link NintekKit, which reads and writes the
App Group defaults, and `UserDefaults` is a required-reason API: an upload with
an undeclared use is rejected outright with ITMS-91053. The reasons are `CA92.1`
(the app's own defaults) and `1C8F.1` (the group). The app's manifest also lists
what the account collects — name, email, user id, photos, project content — all
linked to the user, none of it tracking, all of it App Functionality. Those
answers are cross-checked against App Store Connect, so change both or neither.

**The photo library has no usage string, on purpose.** Photos only ever arrive
through `PhotosPicker`, which runs out of process and hands back the one image
the user chose; the app never touches `PHPhotoLibrary`. Declaring
`NSPhotoLibraryUsageDescription` anyway would ask for access it doesn't use,
which reviewers read as overreach. `NSCameraUsageDescription` is real — see
`CameraPicker`, which is `sourceType = .camera` only.

**Account deletion is server-first.** Guideline 5.1.1(v) requires any app that
creates an account to let the user initiate permanent deletion in-app. The
Account section in More puts that action beside Sign Out, explains what leaves,
offers the JSON backup immediately above it, and protects the irreversible call
with a system destructive-confirmation alert. It calls authenticated
`DELETE /api/account`; the server derives the account from the bearer token,
never from a client-supplied user id.

The client clears credentials, widgets, Spotlight, pending shares, reminders,
decoded-image memory and the starter-seed marker **only after** the server
confirms deletion. A network or server failure leaves the session intact and
the action retryable; local success-shaped cleanup must never hide server data
that still exists.

Sign in with Apple has one extra obligation: deleting Workshop data is not
enough — Apple's token must be revoked too. Every Apple sign-in therefore sends
both `identityToken` and the short-lived `authorizationCode` to
`POST /api/auth/apple`. The server exchanges the code using credentials that
must never ship in the app, stores the resulting Apple refresh token encrypted,
and revokes it with Apple before deleting the account. Microsoft deletion
removes the Workshop account only; it does not delete the user's Entra account.

## Failing safely

Two shapes of bug turned up often enough to be worth naming.

**`Int(_:)` traps.** It is a runtime crash on infinity, NaN, and anything past
`Int64` — not a clamp and not an optional. Any value that came from a text field
is hostile: a `.decimalPad` still reaches 1e22 by holding down a key, and paste
ignores the keyboard entirely. Screen with `isFinite` and a range before
converting (`toFrac32` in `ConversionTablesView`).

**A save that is several round trips can half-succeed.** The project forms write
the project, then every cut row, then every material. If the network drops in
the middle, the sheet stays open on an error with some of it already on the
server — and the obvious next move, tapping Save again, used to create a second
copy of the project. So each form remembers the id it created
(`createdProjectId` / `createdShaperId`) and stamps each row's `serverId` the
moment it lands. Retrying resumes; it doesn't duplicate. Anything else that
grows a multi-step save needs the same treatment.

Relatedly, `SessionTokenProvider` refreshes through an actor
(`SessionRefresher`). The app fans several requests out at once, and without
coalescing each one that finds the token expired spends the *same* refresh
token; a backend that rotates them answers the first and rejects the rest, and
every loser clears the Keychain and signs the user out of a session that was
fine. The unexpired path stays lock-free.

## The app icon

The icon is shared with the web app and **the web repo owns it**. Sources live in
`workshop/app-store/` — `AppIcon.svg` (default), `AppIcon-dark.svg`, `AppIcon-tinted.svg`.
Do not redraw it here; re-render from those.

`AppIcon.appiconset` carries all three as single 1024×1024 renditions and lets the
system downscale:

| Rendition | Appearance | Treatment |
|---|---|---|
| `AppIcon-1024.png` | default | The mark as drawn |
| `AppIcon-1024-dark.png` | `luminosity / dark` | Steel gradient pulled down; flap, `W` and lamp untouched |
| `AppIcon-1024-tinted.png` | `luminosity / tinted` | Mapped to value alone, lamp forced to white so it stays brightest under any user tint |

Three rules, all of which produce a silently wrong icon if broken: **full bleed** (iOS
applies its own superellipse mask — rounding the artwork too leaves a light fringe),
**no alpha channel** (App Store submission rejects it), and **opaque dark/tinted
variants** rather than transparent ones, because the mark is a physical object and
letting the system background show through the frame breaks it.

`AccentColor` is `#C77800` — `accentDeep`, the same amber the board tints with.

Verify by inspecting the compiled catalog rather than the Home Screen; SpringBoard
does not re-render icons when `simctl ui … appearance` changes:

```
xcrun assetutil --info <build>/Workshop.app/Assets.car | grep -A2 AppIcon
```

Expect `UIAppearanceDark` and `ISAppearanceTintable` renditions alongside the default.

## The first board

An empty board is the worst first impression this app can make — a departure
board with no departures. So a brand-new account gets seeded once, on the first
load that comes back genuinely empty (`StarterProjects` / `StarterSeeder`): four
projects and three Shaper builds, all real records the user can edit or delete.
The guard is marked **before** the writes, so a seed that half-fails can't come
back on the next pull-to-refresh and duplicate what did land.

A seed is only worth having if it looks like a project someone kept. The first
version created bare `ProjectInput`s, which landed on the board reading PARTS 0
and EST. COST $0.00 — teaching a new user that a Workshop project is an empty
shell. So each starter carries a cut list, a costed material list, numbered
build steps and a plan sheet. Those are four separate endpoints, so `seed` walks
the projects one at a time (to keep "last updated" order matching the list
order) and fans the children of each out concurrently — they don't depend on
each other, and row order travels in `sortOrder`, not in insertion order. Every
child write is individually non-fatal: a project missing one of its ten parts is
still worth having.

**The seed content is original, and has to stay that way.** Hotlinking photos
and build steps from plans blogs into every new user's account is a copyright
problem and a broken-link problem, and it's the kind of thing App Review reads
as shipping someone else's content. So the prose is written for this app, and
the drawings are generated by `Scripts/make-starter-plans.swift` — orthographic
plan sheets in Martian Mono on steel, deliberately monochrome because the signal
lamp is user-swappable and these bytes are baked at build time. `sourceUrl` is
left empty on purpose: there is no original elsewhere to link to. The sheets are
drawn from the same dimensions as the cut lists, so a part size changes in both
places or in neither.

## Verifying a change

There are no tests and no linter. Build with:

```
xcodebuild -project Workshop.xcodeproj -scheme Workshop \
  -destination 'platform=iOS Simulator,name=<sim>' build
```

Re-run `xcodegen generate` after adding any `.swift` file, or the build will
fail with "cannot find X in scope".

**Close the project in Xcode before regenerating.** If Xcode has it open, it
re-reads the rewritten `project.pbxproj` and re-resolves the package graph. If
that resolve fails for any reason, Xcode keeps the *empty* graph and every
target fails with *"Missing package product 'NintekKit'"* — a misleading error,
since nothing is wrong with the local package and `xcodebuild` on the same file
still succeeds off its cached resolution. Recover with:

```
xcodebuild -project Workshop.xcodeproj -scheme Workshop -resolvePackageDependencies
```

then close and reopen the project. Check that resolve prints a real path for
NintekKit — `NintekKit: (null)` means the graph is broken.

Package resolution needs the network, so builds must use the **default**
DerivedData path. Passing `-derivedDataPath` forces a fresh MSAL resolve and
fails with "Couldn't get the list of tags".

SwiftPM keeps its mirrors as **bare** git repos under
`SourcePackages/repositories`, so resolution breaks under
`safe.bareRepository=explicit` with the same "Couldn't get the list of tags".
Some sandboxed/agent shells inject that setting; if resolve fails there, unset
it for the command rather than deleting `SourcePackages` — deleting it destroys
a working resolution that can only be rebuilt online.

## MSAL has no symbols of its own

MSAL is a SwiftPM `.binaryTarget` — a prebuilt, stripped XCFramework Microsoft
publishes as a zip. Nothing in this build compiles it, so nothing produces a
dSYM for it, and every App Store upload used to come back with *"Upload Symbols
Failed … did not include a dSYM for the MSAL.framework"*. The build is accepted
either way; the cost is that crash reports with an MSAL frame arrive
unsymbolicated.

Microsoft does publish the symbols, as a separate release asset
(`MSAL-iOS.framework.dSYM.zip`, or `MSAL-iOS-Sim…` for the simulator slice —
they are separate builds with separate UUIDs). `Scripts/embed-msal-dsym.sh`
runs as a post-build phase on the app target: it reads the version SwiftPM
actually pinned from `Package.resolved` (not the floating `from:` in
`project.yml`), fetches that release's dSYM into `.dsyms/` keyed by version and
slice, checks its UUID against the binary being linked, and copies it into
`DWARF_DSYM_FOLDER_PATH` so Xcode collects it into the archive.

It gates on `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`, which is the real
precondition — builds that produce no dSYMs at all skip it and never touch the
network. **Every failure path warns and exits 0**: missing symbols cost
symbolication, and that is never worth failing a release build over, least of
all offline. A UUID mismatch is treated as a failure, because symbolicating
MSAL frames against the wrong build is worse than not symbolicating them.

This script is **shared verbatim with ShopKeep** (same filename, same contents
apart from the `.xcodeproj` name). Both ports hit this identically, so fix it in
one place and copy across rather than letting the two drift.

To inspect a screen against real data without driving auth, the app reads these
environment overrides (`WORKSHOP_START_*` are `#if DEBUG` only):

`WORKSHOP_API_BASE`, `WORKSHOP_DEV_TOKEN`, `WORKSHOP_DEV_USER_KEY`,
`WORKSHOP_START_TAB`, `WORKSHOP_START_PROJECT`, `WORKSHOP_START_SHAPER`,
`WORKSHOP_SIDEBAR=open`

`WORKSHOP_SIDEBAR=open` exists because the sidebar starts collapsed on iPad and
its toggle can only be tapped by hand — `simctl` has no tap command, so the
sidebar is otherwise invisible to an automated pass.

**Always set `WORKSHOP_DEV_USER_KEY`.** `WORKSHOP_DEV_TOKEN` alone leaves
`userKey` nil, which silently suppresses every `?oid=`-scoped image URL — so
the whole app renders photo-free and image layout bugs pass a local sweep
untouched. That is exactly how a card-image overflow shipped once already.

**Check the regular size class too.** iPad and "Designed for iPad" on a Mac use
`NavigationSplitView` and much wider grids; an adaptive column count that looks
right on a phone can lay out more columns than there are cells.

Pass them through `simctl` as `SIMCTL_CHILD_*`. **Always check both renditions** —
every defect found late in this port was a dark-mode contrast failure.
