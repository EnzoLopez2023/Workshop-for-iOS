---
name: Workshop for iOS
description: A living plan table that keeps the next woodworking action on top.
colors:
  canvas: "light-dark(#EEF4F2, #0C1513)"
  layer-recessed: "light-dark(#E0EBE7, #12201D)"
  layer-raised: "light-dark(#FAFCFB, #182823)"
  ink: "light-dark(#15332E, #F3F8F6)"
  muted-ink: "light-dark(#58716B, #9CB2AC)"
  divider: "light-dark(#C9DAD5, #2A423C)"
  navigation-material: "light-dark(#E7F0ED, #172923)"
  navigation-deep: "light-dark(#15332E, #09110F)"
  navigation-highlight: "light-dark(#FFFFFF, #254039)"
  on-navigation: "light-dark(#15332E, #F3F8F6)"
  metric-face: "light-dark(#F7FAF9, #1A2B26)"
  metric-face-low: "light-dark(#E5EFEC, #12201D)"
  metric-ink: "light-dark(#15332E, #F2F8F6)"
  success: "light-dark(#2F7657, #76CFA5)"
  success-fill: "light-dark(#3F936D, #4DAE81)"
  danger: "light-dark(#A64139, #F28A80)"
  danger-fill: "light-dark(#C75A50, #D86C62)"
  spruce-annotation: "light-dark(#176B5B, #68C7B0)"
  spruce-action: "light-dark(#125447, #8AD8C5)"
  spruce-fill: "light-dark(#1E7666, #2A927E)"
  clay-annotation: "light-dark(#96513E, #E9A08A)"
  clay-action: "light-dark(#743D2F, #F0B6A5)"
  clay-fill: "light-dark(#A95F49, #C97C65)"
  moss-annotation: "light-dark(#557A43, #9BCB82)"
  moss-action: "light-dark(#3F5E32, #B5DEA0)"
  moss-fill: "light-dark(#668E50, #79A962)"
  pencil-blue-annotation: "light-dark(#356D85, #7AB9D3)"
  pencil-blue-action: "light-dark(#29566A, #A0D0E2)"
  pencil-blue-fill: "light-dark(#477F97, #5B9DB8)"
  iris-annotation: "light-dark(#66568E, #B5A4DE)"
  iris-action: "light-dark(#4D416D, #CFC3EB)"
  iris-fill: "light-dark(#7868A2, #9281BD)"
typography:
  display:
    fontFamily: "SF Rounded, SF Pro Rounded, system-ui"
    fontSize: "34pt"
    fontWeight: 700
  headline:
    fontFamily: "SF Rounded, SF Pro Rounded, system-ui"
    fontSize: "20pt"
    fontWeight: 700
  title:
    fontFamily: "SF Rounded, SF Pro Rounded, system-ui"
    fontSize: "17pt"
    fontWeight: 600
  body:
    fontFamily: "SF Pro, system-ui"
    fontSize: "17pt"
    fontWeight: 400
  label:
    fontFamily: "SF Rounded, SF Pro Rounded, system-ui"
    fontSize: "12pt"
    fontWeight: 600
rounded:
  compact: "10pt"
  control: "14pt"
  hero: "24pt"
  capsule: "999pt"
spacing:
  compact: "8pt"
  small: "12pt"
  card: "16pt"
  canvas: "20pt"
  generous: "28pt"
components:
  action-primary:
    backgroundColor: "{colors.spruce-action}"
    textColor: "#FFFFFF"
    typography: "{typography.title}"
    rounded: "{rounded.control}"
    padding: "0 16pt"
    height: "48pt"
  card-glass:
    backgroundColor: "{colors.layer-raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "{spacing.card}"
  search-field:
    backgroundColor: "{colors.layer-raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "0 14pt"
    height: "50pt"
  sidebar-destination:
    backgroundColor: "{colors.layer-recessed}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    padding: "0 13pt"
    height: "48pt"
  status-capsule:
    backgroundColor: "{colors.layer-recessed}"
    textColor: "{colors.muted-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.capsule}"
    padding: "6pt 10pt"
---

# Design System: Workshop for iOS

## Overview

**Creative North Star: "The Living Plan Table"**

Workshop is a cool, native drafting surface rather than a dashboard of summaries. A project is treated as one living plan: its drawing or photograph establishes context, its current stage explains progress, and a translucent action sheet puts the next useful move physically on top. The visual character comes from vellum, spruce drawing ink, pencil annotations, restrained frosted layers, and Apple system geometry.

This is an Operate system. Native navigation, controls, gestures, Dynamic Type, and accessibility settings outrank visual expression. Brand lives in the plan grid, the layered-project composition, the hammer mark, the adaptive annotation palette, and the disciplined 14-point squircle—not in replacement platform chrome.

**Key Characteristics:**

- Cool adaptive vellum surfaces with deep spruce ink.
- A 24-point drafting grid behind content, never a decorative card texture.
- SF Rounded for focal titles and compact data; SF Pro for reading and controls.
- Native material used only where a physical tracing or chrome layer is needed.
- One active project leads; the rest of the workshop follows as a browsable library.
- Continuous geometry, 44-point minimum targets, and semantic labels throughout.

**Source of truth:** `Workshop/App/Palette.swift` owns adaptive colors and annotation presets; `Workshop/App/Theme.swift` owns type helpers, geometry, glass, the plan canvas, and shared primitives; `Workshop/App/RootView.swift` owns the device shell; `Workshop/Screens/**` and `Workshop/Auth/SignInView.swift` own shipped compositions; `WorkshopWidgets/WidgetSupport.swift` and the other `WorkshopWidgets/**` files own extension-safe adaptations. The packaged icon renditions in `Workshop/Assets.xcassets/AppIcon.appiconset/` and plan PNGs in `Workshop/Resources/StarterPlans/` are the runtime asset truth.

**The Shipped Artifact Rule.** Compatibility names left from an earlier implementation carry no visual authority. New work follows the values and behavior they now resolve to.

## Colors

The palette is a two-axis system: every structural role adapts between light and dark, while the user may independently choose one of five annotation families.

### Primary

- **Spruce Annotation:** The default drawing-note color and quiet emphasis.
- **Spruce Action:** The higher-contrast default for tints, active controls, stage progress, and selected navigation.
- **Spruce Fill:** The saturated companion for compact filled marks and widget figures.

### Secondary

- **Pencil Blue:** A drafting-note family available as a complete annotation, action, and fill preset. `Theme.pencil` deliberately remains the base Pencil Blue annotation even when another preset is selected.
- **Clay, Moss, and Iris:** Full three-token alternatives. They replace the annotation axis only; they do not recolor vellum, ink, dividers, or semantic state.

### Tertiary

- **Success / Success Fill:** Completion and positive state.
- **Danger / Danger Fill:** Destructive state and errors.
- Status always includes a word or symbol; green and red never carry meaning alone.

### Neutral

- **Canvas:** The app-wide cool vellum ground.
- **Layer Recessed / Layer Raised:** Secondary wells and translucent-card fallback surfaces.
- **Ink / Muted Ink:** Primary reading color and secondary explanation.
- **Divider:** Hairlines, grid strokes, and subtle component boundaries.
- **Navigation Material / Deep / Highlight:** The tonal ingredients behind native blurred navigation.
- **Metric Face / Low / Ink:** Compatibility roles for compact data surfaces and widget figures, not a separate visual world.

### Annotation presets

`Palette.all` presents presets in this order: Spruce, Clay, Moss, Pencil Blue, Iris. Each preset contains base annotation, high-contrast action, and saturated fill tokens, and every member has a light and dark value. The selection persists under `ws.accent`; unknown or retired identifiers fall back to Spruce. Widgets intentionally use Spruce because their process cannot observe the app's `ThemeManager`.

### Named Rules

**The Independent Axes Rule.** Appearance and annotation selection are independent. Switching to dark mode never changes the selected annotation family, and switching annotation never recolors structural surfaces.

**The Annotation, Not Wallpaper Rule.** Annotation color marks actions, current stages, counts, and drafting notes. It does not flood the plan canvas or replace semantic success and danger.

**The Contrast Has a Companion Rule.** Use each preset's action token for control tint and text emphasis, and its fill token for compact solid marks. Do not assume the base annotation is legible as filled-control text.

## Typography

**Display Font:** SF Rounded through the system font API

**Body Font:** SF Pro through the system font API

**Label/Mono Font:** SF Rounded with monospaced digits only for numeric readouts

**Character:** Rounded system type makes project titles and measurements approachable without introducing a display typeface foreign to iOS. Default SF Pro keeps longer instructions, forms, and system controls familiar and highly legible.

### Hierarchy

- **Display** (bold, 34pt base): Sign-in promise, large project titles, and singular focal moments.
- **Headline** (bold, 20pt base): Next actions and major content emphasis.
- **Title** (semibold, 17pt base): Navigation, card titles, rail headings, and primary actions.
- **Body** (regular, 17pt base): Instructions, fields, and ordinary reading.
- **Label** (semibold, 12pt base): Status, stage names, metadata, and compact annotations.
- **Caption** (system caption and caption2 roles): Secondary metadata. Numeric values use tabular figures through `monospacedDigit()`.

`Theme.board`, `Theme.ui`, and `Theme.display` retain source-compatible names but all return Apple system fonts. Custom base sizes pass through `UIFontMetrics` relative to the supplied SwiftUI text style. Native text-style calls inherit Dynamic Type directly. `Theme.boardFixed` is reserved for the text-size picker's fixed comparison samples and is not a general escape hatch.

### Named Rules

**The System Scale Rule.** Use semantic SwiftUI text styles first. When an exact base size is necessary, route it through `Theme` so `UIFontMetrics` scales it.

**The Rounded Focus Rule.** SF Rounded belongs to project names, section rails, status, compact data, and actions; prose and form content stay in default SF Pro.

**The No Display Font Rule.** Do not restore bundled condensed or custom display faces to the interface. The shipped visual system is native SF typography.

## Layout

The global spatial model is a centered plan canvas with an adaptive reading column. `ContentColumnLayout` defaults to 640pt and reclaims one third of width beyond its cap instead of leaving dead side bands; the dashboard requests a 900pt working column. Screen content generally begins with a 20pt canvas inset, 16pt card rhythm, and larger section separation only where content groups change.

The plan canvas is a top-leading to bottom-trailing gradient of canvas and recessed tones. A 24pt orthogonal grid is drawn with 0.5pt divider strokes at 18% opacity and hidden from accessibility.

The dashboard keeps one navigation stack but exposes two sibling content pages
through a persistent native segmented switcher directly below the navigation
bar. The switcher is the only project-type filter and remains visible while page
content scrolls. Its selected page persists per scene; Projects search, Shaper
Hub search, and the Projects-only status filter remain independent local state.

- **Projects page:** Active build, next action, status filter, regular project
  library, templates, and inspiration.
- **Shaper Hub page:** Contextual search followed immediately by the Shaper/CNC
  project library, with a dedicated count and distinct empty and no-results
  states; no active-project hero, summary wall, or regular status controls.

Project deep links, shared-item intake, and regular-project creation select
Projects before presenting or pushing. Shaper routes and creation select Shaper
Hub. Both route types append to the same navigation path, so returning from
detail preserves the selected dashboard context.

The Projects page's active-project composition is intentionally different by size class:

- **Compact / iPhone:** A 310pt plan or photograph is followed by the next-action glass layer with a 34pt overlap and 16pt side/bottom inset.
- **Regular / iPad:** The plan and action layer share a minimum 380pt hero. The action layer floats on the trailing side at 300–380pt wide with a 28pt inset.
- **Library:** Project cards use an adaptive grid with a 280pt minimum and 16pt gaps; template cards use a 220pt minimum.

iPhone is portrait-only in `Workshop/Info.plist` and `project.yml` and always uses the four-destination native tab shell. iPad supports portrait, upside-down portrait, and both landscape orientations. At regular width it uses a persistent `NavigationSplitView` with `.balanced` behavior and a 216–272pt sidebar; narrow split or Slide Over falls back to tabs. The split view and its native collapse behavior remain intact in both iPad orientations. Every shell uses the same two-page dashboard model and switcher behavior.

**The Active Layer Rule.** On the Projects page, the first useful viewport
belongs to the active project and its next action. Counts, search, remaining
projects, templates, and inspiration follow rather than competing above it.

**The Type Separation Rule.** Regular and Shaper Hub projects never share one
grid. The dashboard switcher changes the whole project context; regular status
filter state and each page's search query remain independent.

**The Platform Shell Rule.** Device idiom and size class select the shell. Do not infer iPad behavior from orientation or let an iPhone replace its navigation tree during rotation.

## Elevation & Depth

Depth is a restrained hybrid of tonal layering, native blur, and soft vertical shadow. `planGlass` uses `.ultraThinMaterial`, a 1pt divider stroke at 62% opacity, and an optional deep-spruce shadow. Standard glass lifts by 8pt with a 16pt blur at 12% opacity; library cards use 7pt / 14pt / 10%; the active hero uses 10pt / 22pt / 14%; the iPad sidebar uses 8pt / 18pt / 12%.

Navigation bars and tab bars use `systemUltraThinMaterial` with raised-surface color at 58% and 66% respectively. When Reduce Transparency is enabled, the sidebar resolves to an opaque raised surface and sign-in strengthens its vellum veil. Glass is a functional layer—navigation chrome, action tracing sheet, card, or modal—not ambient decoration.

### Shadow Vocabulary

- **Tracing Layer:** 0 8pt 16pt deep-spruce at 12%; standard elevated glass.
- **Library Sheet:** 0 7pt 14pt deep-spruce at 10%; image-forward project cards.
- **Hero Plan:** 0 10pt 22pt deep-spruce at 14%; the single active project.
- **Sidebar Rail:** 0 8pt 18pt deep-spruce at 12%; the persistent iPad workbench rail.

### Named Rules

**The Native Glass Rule.** Use Apple material for layers that must visibly sit above content. Use adaptive solid fallbacks when transparency is reduced.

**The One Hero Rule.** Only the active project earns hero depth and 24pt clipping. Ordinary cards use the standard 14pt system.

## Shapes

The default form is a continuous 14pt squircle. It is used for buttons, search, glass cards, sidebar destinations, and common containers. Compact utility wells may use 10pt; the active project's large clipped plan uses 24pt. Status and stage labels are capsules because they represent compact state, not because pills are a general container style.

Borders are 1pt adaptive divider strokes, usually softened to 62–70% opacity over material. Controls preserve at least a 44×44pt interactive region even when the visible glyph is smaller. Image wells clip visually and define their own content shape; decorative fill images disable hit testing so oversized image content cannot steal neighboring taps.

**The Fourteen-Point Default Rule.** Begin every interactive surface and ordinary card at a 14pt continuous radius. Depart only for a documented compact well, capsule state, or the singular hero.

**The Visible Bounds Rule.** Clipping an image is not enough. Its hit shape must match the visible card, and the image itself is noninteractive inside a larger navigation target.

## Components

### Buttons

- **Shape:** Continuous 14pt squircle, normally 48pt high; authentication plates are 52pt high. Toolbar glyphs sit in a 38pt visual well inside a 44pt target.
- **Primary:** Palette action color with white SF Rounded semibold text. Press feedback scales to 97% and fades to 82% over 160ms.
- **Secondary:** Raised adaptive surface or clear material with ink/action text and a divider stroke when needed.
- **Danger:** Semantic danger fill with white content, never annotation redirection.
- **Focus / Pointer:** Native focus behavior remains. iPad cards and the active project use `.hoverEffect(.highlight)`; sidebar rows add a faint hover wash. Hover never reveals an otherwise hidden action.

### Chips

- **Status:** Capsule with both text and semantic tone. Image-backed status adds an ultra-thin material halo for contrast.
- **Counts:** Quiet annotation tint with action-colored tabular figures.
- **Stages:** A four-step Idea / Plan / Build / Done track uses color plus current-dot or completed-check state and exposes one VoiceOver label for the whole track.

### Cards / Containers

- **Corner Style:** 14pt continuous for ordinary cards; 24pt for the active hero.
- **Background:** Ultra-thin material over the plan canvas, with raised-surface fallback.
- **Border:** One-point adaptive divider, commonly at 62%.
- **Internal Padding:** 16pt for standard cards, 20pt for the next-action sheet.
- **Project Card:** A bounded 16:9 image or plan surface, optional material-backed status, then title, description, wood, parts, and hours. The card merges children into one useful accessibility summary.

### Inputs / Fields

- **Style:** Native controls retain native behavior. Search uses a 50pt non-elevated glass field with 14pt horizontal inset and muted leading magnifier.
- **Focus:** System keyboard, focus, correction, and selection behavior wins. Search disables capitalization and autocorrection because it matches project and material names.
- **Error / Disabled:** Errors use danger color and explanatory text. Disabled controls retain their label and native disabled semantics.

### Navigation

iPhone uses the native four-tab shell; iPad uses the balanced split view and persistent frosted sidebar. Within the single Dashboard destination, a frosted safe-area inset pins the native Projects / Shaper Hub segmented control directly below navigation. The selected segment uses the current annotation action tint with white text in light mode and deep navigation ink in dark mode, so the active project type is unmistakable without abandoning the native control. Selection persists through scene storage and crossfades sibling content without replacing the `NavigationStack`; the crossfade is removed under Reduce Motion. Projects alone exposes the status-filter toolbar item. The add toolbar item is a native menu that always offers both project types and selects the matching page before presentation. Project deep links, shared-item intake, and regular quick creation select Projects; Shaper routes and creation select Shaper Hub. Both route types use one path, preserving native back and return behavior. Navigation stacks, sheets, back buttons, edge-swipe gestures, tab behavior, toolbar placement, sheet detents, and drag indicators stay native. The hammer mark and annotation tint identify Workshop without replacing platform interaction.

### Active Project Layer

The project plan or photograph is the base layer. A dark lower gradient protects the white title and status over imagery. The action sheet supplies a symbol, action title, explanation, parts/hours, stage track, and a full-width Open Project control. The outer navigation target has one combined label and hint; inner visuals are decorative to accessibility.

### Widgets and Live Activities

Widget extensions mirror the default Spruce palette and system type in `WorkshopWidgets/WidgetSupport.swift`; they do not import the app's runtime theme selection. Home Screen widgets disable system content margins and paint to the container edge. Stats adapt between a focused small view and four equal medium cells; in-progress work adapts from two medium rows to six large rows; shopping adapts between small and medium; Lock Screen widgets use the circular, rectangular, and inline accessory families.

Figures use compact SF Rounded with monospaced digits and minimum scale factors. Rows divide available height evenly, and empty slots retain structure rather than collapsing. Live Activities and Dynamic Island regions keep the same canvas, annotation, semantic state, and compact data hierarchy while following each system region's constraints.

**The Static Extension Rule.** Widgets preserve the visual language at rest. They compress hierarchy by family and use native links/intents; they do not reproduce app-only animation or runtime palette switching.

### App Icon and Starter Plans

The app icon ships as opaque, full-bleed 1024×1024 default, dark-luminosity, and tinted-luminosity renditions. All three show layered translucent plan sheets, a drafting grid and dimension line, and the hammer silhouette. iOS supplies the outer mask; do not round the source artwork or add alpha.

Seven bundled 1600×1100 starter-plan PNGs are part of the first-run material system. The shipped sheets use light vellum, a pale wood surround, spruce outlines, pencil-blue dimensions and notes, a small wood swatch, and restrained sheet depth. Their drawing geometry corresponds to the editable starter records in `Workshop/App/StarterProjects.swift`. `Scripts/make-starter-plans.swift` is the generator location, but packaged PNGs remain the visual runtime authority whenever generator comments or colors diverge.

### Accessibility and Motion

Every custom action preserves a 44pt minimum target. Important image cards combine child content into explicit labels; icons that repeat visible text are hidden; state uses words, symbols, and traits as well as color. Reduce Motion freezes the sign-in plan drift and removes or simplifies active-layer, loading, metric, and toast animation. Reduce Transparency substitutes solid adaptive surfaces or stronger veils. Pointer highlights are additive feedback for iPad and never a prerequisite.

## Do's and Don'ts

### Do:

- **Do** start with `Palette.swift` and `Theme.swift`; reuse adaptive roles rather than embedding new light-only colors.
- **Do** keep the active plan/photo and next-action layer dominant before search and library content.
- **Do** keep regular and Shaper Hub libraries on separate sibling dashboard pages; persist the selected page per scene while retaining independent search and Projects-only status state.
- **Do** use semantic SwiftUI type styles or the `Theme` helpers so `UIFontMetrics` and Dynamic Type remain active.
- **Do** use native material only for an actual raised layer and provide the shipped Reduce Transparency behavior.
- **Do** preserve the 14pt default geometry, 44pt targets, native navigation, VoiceOver summaries, and pointer-as-enhancement behavior.
- **Do** adapt widget density to family while retaining equal row structure and the default Spruce annotation.
- **Do** treat the packaged app-icon and starter-plan assets as visual evidence; preserve their variant and no-alpha requirements.

### Don't:

- **Don't** revive the former board metaphor, condensed display type, tiny radii, steel bands, split-flap decoration, or summary-metric wall.
- **Don't** let annotation color become a full-screen brand wash or substitute for semantic success and danger.
- **Don't** stack ornamental glass layers; every blur must explain chrome, tracing, selection, or containment.
- **Don't** use hover to disclose required controls, replace native back/tab/sheet behavior, or key responsive structure to orientation alone.
- **Don't** duplicate project type inside the status filter or create a second dashboard navigation stack.
- **Don't** use fixed custom font sizes without `UIFontMetrics`, hide state in color alone, or ship a custom control below 44pt.
- **Don't** treat legacy helper names or stale generator prose as permission to reintroduce a retired visual device.
