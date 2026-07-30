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

## Verifying a change

There are no tests and no linter. Build with:

```
xcodebuild -project Workshop.xcodeproj -scheme Workshop \
  -destination 'platform=iOS Simulator,name=<sim>' build
```

Re-run `xcodegen generate` after adding any `.swift` file, or the build will
fail with "cannot find X in scope".

To inspect a screen against real data without driving auth, the app reads these
environment overrides (`WORKSHOP_START_*` are `#if DEBUG` only):

`WORKSHOP_API_BASE`, `WORKSHOP_DEV_TOKEN`, `WORKSHOP_DEV_USER_KEY`,
`WORKSHOP_START_TAB`, `WORKSHOP_START_PROJECT`, `WORKSHOP_START_SHAPER`

**Always set `WORKSHOP_DEV_USER_KEY`.** `WORKSHOP_DEV_TOKEN` alone leaves
`userKey` nil, which silently suppresses every `?oid=`-scoped image URL — so
the whole app renders photo-free and image layout bugs pass a local sweep
untouched. That is exactly how a card-image overflow shipped once already.

**Check the regular size class too.** iPad and "Designed for iPad" on a Mac use
`NavigationSplitView` and much wider grids; an adaptive column count that looks
right on a phone can lay out more columns than there are cells.

Pass them through `simctl` as `SIMCTL_CHILD_*`. **Always check both renditions** —
every defect found late in this port was a dark-mode contrast failure.
