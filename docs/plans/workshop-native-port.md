# Workshop → Native SwiftUI Port ("Workshop for iOS") — Full Phased Plan

> **COLD-START NOTE (for a fresh session with no prior context):** This plan is
> self-contained — all decisions below were made with Enzo on 2026-07-22 after a
> full exploration of the React app, its backend, and the completed ShopKeep port.
> Before writing any code, skim these three references:
> 1. `/Users/enzo/repos/Xcode - SwiftUI/NintekKit/docs/NATIVE_PORT_PLAYBOOK.md` — the port rules (esp. "the .tsx is the spec, not the screenshot").
> 2. `/Users/enzo/repos/Xcode - SwiftUI/ShopKeepNative/` — the completed sibling port; lift its patterns per the "Reusable assets" section below.
> 3. `/Users/enzo/repos/VSCode - React/workshop/` — the app being ported; `server.js` is the API contract.
> Work phase by phase, commit-and-push per feature, bump the version every commit,
> and pause for Enzo's device-testing loop at the end of each phase.

## Context

Port the Workshop React app (`/Users/enzo/repos/VSCode - React/workshop` — woodworking project journal: projects, cut lists, materials, cut-plan optimizer, Shaper CNC hub, shopping list, build/finish logs) to a native SwiftUI app at `/Users/enzo/repos/Xcode - SwiftUI/Workshop for iOS`. This is the next port in the portfolio strategy (Cairn → ShopKeep → **Workshop**), executed with every lesson from the ShopKeep port (23+ commits, v1.6.0, playbook at `NintekKit/docs/NATIVE_PORT_PLAYBOOK.md`). End state: near-identical native app matching the web's features and warm cream/rust editorial look, plus native additions (haptics, widgets, Sign in with Apple, App Intents). This plan lives at `Workshop for iOS/docs/plans/workshop-native-port.md` — keep it updated (check off phases, record decisions) as the port progresses.

**Locked decisions (Enzo):**
| Axis | Decision |
|---|---|
| Auth | **Both providers, like ShopKeep v2.4.0** — port ShopKeep's dual-auth (Entra + Apple→server-session) to workshop/server.js; native offers Microsoft (MSAL) + Sign in with Apple. Data keyed per provider. |
| Sync | Non-negotiable — keep Azure backend; native = SwiftUI client of existing API |
| Audience | Personal / TestFlight near-term |
| Targets | iPhone + iPad adaptive (ShopKeep RootView pattern) |
| Notebook (Tabloom) | **Skip for v1** (dead server tables; it's a separate Tabloom-token integration) |
| Widgets | In-progress projects + project stats |
| AI URL-import | Include both (projects + Shaper) — call existing analyze-url endpoints |
| Typography | **System font only** (SF app-wide, like ShopKeep native — no serif headers) |
| Versioning | project.yml single source of truth; **bump every commit** (semver marketing + monotonic build), start 0.1.0 → 1.0.0 at TestFlight |

## Key exploration facts

### The web app (the spec — "the .tsx is the spec, not the screenshot")
~7.9k LOC TS/TSX. Pages: Dashboard 427 · ProjectForm 928 · ProjectDetail 1054 · ShaperProjectForm 500 · ShaperProjectDetail 307 · ConversionTables 320 (pure client) · ShoppingList 199 · Settings 231 · Notebook (skipped). Components: CutPlanOptimizer 505 · CutPlanSheet 167 (SVG diagrams) · CommandPalette 213 · cards/skeletons/lightbox.
- **`src/lib/cutPlan.ts` (331 LOC, pure TS, zero deps)** — guillotine/BSSF packer (`optimizeCuts`, `guillotineSplit`, `bssfScore = leftoverShort*1e6+leftoverLong`) + **`parseInches`** (fractions, feet-inches, vulgar fractions, smart quotes — load-bearing, port carefully).
- Design tokens (`src/index.css`): cream `#F5F0EA`, paper `#FFF`, ink `#1C0F07`, muted `#8B7A6B`, rust `#A0522D`, line `#EDE8E3`; dark mode walnut/copper under `[data-theme=dark]`; 5 accent presets (rust/forest/slate/amber/navy); per-route photo backgrounds with veil. Same family as ShopKeep — reuse ShopKeep's `Theme`/`Palette` architecture with Workshop values.

### The backend (`workshop/server.js`, 1594 lines — keep, extend for Apple)
- Express 5 + better-sqlite3, **per-user DB** `USERS_DIR/<oid>.db`, jose JWKS validation. **Stricter than ShopKeep:** single issuer (`…/v2.0`) + single audience (`API_AUDIENCE`), Entra-only, `OID_RE` GUID-only user keys. Native MSAL tokens + Apple keys need ShopKeep's `ACCEPTED_ISSUERS`/`ACCEPTED_AUDIENCES`/`USER_KEY_RE` treatment.
- ~50 snake_case routes: projects CRUD (fat detail aggregate: images/cut_list/materials/build_log/finish_log/links), images (**multipart** upload, disk storage, 200MB, MIME-sniffed, PDFs allowed; GET auth-exempt via `?oid=`), cut-list, materials (+`PATCH …/purchased`), shopping-list, build-log (multipart photo), finish-log, links, templates (save-as/clone), shaper-projects (+images/cut-list), cut-plan-config (opaque JSON `{config:…}`), 2× AI analyze-url (Claude `claude-sonnet-4-6`, 30/h rate limit).
- Decoder gotchas: dimensions are **strings** ("27 1/2"); `purchased` bool; `wood_types`/`tools_needed` hydrated arrays; mixed create responses (full object vs `{id}` vs `{success:true}`); most fields nullable.
- Deploy: Azure App Service container `app-workshop-prod-lwxhu7jxlrbtu` (GH Actions → ACR on push to main), custom domain `workshop.enzolopez.net`, data at `/home/data`. **Entra client/tenant GUIDs are NOT in the repo** — pull from App Service config (`AZURE_TENANT_ID`, `API_AUDIENCE`, `VITE_AZURE_CLIENT_ID`) before auth wiring.

### Reusable ShopKeep-port assets (lift wholesale)
- `ShopKeepNative/ShopKeep/App/Theme.swift` + `Palette.swift` + `ThemeManager` — token architecture, `skCard()`, `creamBackground()`, `contentColumn()`, `AppInfo.version`, `Eyebrow`.
- `App/RootView.swift` — `AppDestination` enum, iPad `NavigationSplitView` (portrait-collapse/landscape-both, sidebar 216/260/272, brand header + signed-in/version footer, `.ignoresSafeArea(.keyboard)` fix), iPhone `TabView`.
- `Auth/MSALAuth.swift` (keychain-group gotcha), `Auth/AppleAuth.swift` + `AppleSessionStore` + `SessionTokenProvider` (refresh ≤60s of expiry), `SignInView` (both buttons, Apple name capture), `AppModel` provider-picking init, `onOpenURL` deep-link-then-MSAL.
- `App/AuthImage.swift` (actor cache) — adapt: Workshop images are `?oid=`-scoped GETs, so build URL with `?oid=<userKey>` (like web) rather than bearer-only.
- `TaxonomyEditor` pattern (config-of-closures CRUD), `FlowLayout`, sort-comparator lesson (swap operands, never negate), search `FocusState` fix, `Exporter`+`ShareSheet`, `CameraPicker`, `ScannerSheet` (if needed later), Widgets extension + `NSExtensionPointIdentifier` trap, deep links via `model.pendingSearch`.
- `NintekKit` — `APIClient` (get/post/put/delete/postRawJSON/deleteWithBody/getData), `TokenProvider` seam, `APIError`, snake_case decoder/encoder config from `ShopKeepAPI.swift` init. **Gap: no multipart support — must add `postMultipart` to APIClient** (Workshop uploads are FormData, not base64 JSON).

### Fresh Xcode template (replace)
Stock SwiftUI+SwiftData template, 1 commit, no remote. Wrong everything: plain Xcode (not xcodegen), deployment target **26.5**, Swift 5.0, bundle id `nintek.com.Workshop-for-iOS` (inverted). **Re-scaffold with xcodegen**: target name `Workshop` (space-free; folder stays "Workshop for iOS"), bundle id `com.nintek.workshop`, iOS 17.0, Swift 6.0, team `3KB968X34U`, version-in-settings pattern. Keep the git repo; add GitHub remote later.

---

## Phase 0 — Prerequisites (backend + config, before any Swift)

> **PROGRESS (2026-07-22): Phase 0 COMPLETE.** 0.3 ✅ re-scaffold (`d10f83d`, iOS repo).
> 0.2 ✅ dual-auth **merged to main + deployed to prod** (workshop repo merge `371184f`),
> verified live: `/api/auth/apple` → 401/400 (enabled, not 503), Entra no-token → 401,
> SPA + `/api/health` → 200. 0.1 ✅ Entra iOS redirect/scope added by Enzo; App Service
> env `SESSION_SECRET` + `APPLE_BUNDLE_ID=com.nintek.workshop` set. **Next: Phase 1.**
> (Deploy note: the GH Actions health-poll can pass against the old container mid
> rolling-swap — re-test prod ~2 min post-deploy before concluding anything.)

**0.1 Pull Entra config** (needs Enzo/az): ~~read `AZURE_TENANT_ID`, `API_AUDIENCE`, `VITE_AZURE_CLIENT_ID`~~ — **the GUIDs are already in the repo** at `.github/workflows/deploy.yml` (`VITE_AZURE_CLIENT_ID: 0f303f8f-207f-4b7f-84a5-b5d0abcf49d1`, `VITE_AZURE_TENANT_ID: 52188f12-db6b-46c6-88ff-08c802f0ed3b`; `API_AUDIENCE` == the client id). No `az` needed for IDs. **Still needs Enzo in the portal:** verify the Entra app registration has **Expose an API** scope (`api://<clientId>/access_as_user`) AND add an **iOS platform redirect** `msauth.com.nintek.workshop://auth` (the two ShopKeep deploy landmines: missing runtime env vars → 503; missing scope → AADSTS500011 login loop). **Plus the new App Service env for 0.2 (below): `SESSION_SECRET`, `APPLE_BUNDLE_ID=com.nintek.workshop` — set these BEFORE merging `feat/dual-auth-apple` to main.**

**0.2 Port dual-auth to `workshop/server.js`** ✅ **DONE (branch `feat/dual-auth-apple`, commit `34297a5`, verified locally, NOT pushed).** As built:
- `ACCEPTED_ISSUERS` (v2.0 + `sts.windows.net/<tenant>/`) + `ACCEPTED_AUDIENCES` (`api://<id>` + bare id) — strict superset of the old single-value check, so no web/Entra regression; fixes the native-token 401.
- Apple path: `APPLE_JWKS`/`APPLE_ISSUER`/`APPLE_AUDIENCES` verify, `POST /api/auth/apple` (id_token → minted HMAC session access+refresh, `apple_<sha256(sub)>` userKey), `POST /api/auth/refresh`, `verifySession`/`mintSession`, `userKeyFromBearer` (own session first, then Entra), `USER_KEY_RE` (GUID or `apple_<64hex>`) gating `getUserDb`+`resolveReadDb`, `upsertProfile`/`readProfile`/`user_profile` table. Gated by `SESSION_SECRET` (`APPLE_AUTH_ENABLED`) → deploys dark, 503s until configured, Entra path unaffected.
- **Empty-seed decision (Enzo, 2026-07-22): new non-primary users get a BLANK schema DB, not a copy of the primary user's data.** Dropped the `copyFileSync(SEED_DB_PATH, …)` in `getUserDb`; the seed snapshot now backs demo mode (`getDemoDb`) only. This closes the exposure that opening Apple sign-in would otherwise create (any Apple ID would have inherited Enzo's real projects). Session names: `SESSION_ISSUER='workshop-api'`, `SESSION_AUDIENCE='workshop-clients'`. Env used: `SESSION_SECRET`, `APPLE_BUNDLE_ID` (native audience), optional `APPLE_WEB_SERVICES_ID` (web, later).
- **Remaining (Enzo):** set App Service env (0.1b) → merge `feat/dual-auth-apple` → main to deploy → verify `/api/health` + a real native token round-trip (**test acceptance, not just rejection** — playbook rule) + web regression.

**0.3 Re-scaffold the Xcode project** ✅ **DONE (iOS repo, commit `d10f83d`).** xcodegen `project.yml` cloned from ShopKeepNative: target `Workshop`, bundle `com.nintek.workshop`, iOS 17, Swift 6, team 3KB968X34U, version 0.1.0/build 1, MSAL+NintekKit. Widgets deferred to Phase 6. `Workshop/App/WorkshopApp.swift` placeholder; builds clean for generic iOS. Dual-auth URL schemes + Apple/App-Group/keychain entitlements declared up front.

## Phase 1 — Foundation (NintekKit + auth + theme + shell)

**1.1 NintekKit additions** ✅ **DONE (NintekKit repo, commit `dd9b4e0`; 19 tests green; iOS app builds against it).** As built: `Models/WorkshopModels.swift` (WSProject with aggregates optional so bare create/update rows decode; WSProjectDetail fat aggregate; all the row/input/analyze types; `CutPlanConfig`/`StockRow` camelCase-coded for web↔native interop), `WorkshopAPI.swift` (~35 routes, snake_case coders, `imageURL(imageId:userKey:)`/`buildLogImageURL(entryId:userKey:)` with `?oid=`, cut-plan-config via plain coders), `APIClient` +`postMultipart`/`patch`/`putRawJSON`/`MultipartFile` (additive — ShopKeep untouched), plus 6 decode tests. `CutPlan.swift` still deferred to Phase 4. Original spec below:
- `Models/WorkshopModels.swift`: `WSProject` (list row + detail aggregate), `WSImage`, `CutListItem`, `WSMaterial`, `BuildLogEntry`, `FinishLogEntry`, `ProjectLink`, `WSTemplate`, `ShaperProject`, `ShoppingItem`, `AnalyzeResult`/`ShaperAnalyzeResult`, `CutPlanConfig` (Codable mirror of the web's stock/kerf config JSON). All optionals-heavy, snake_case-decoded; dimensions as `String`.
- `WorkshopAPI.swift` modeled on `ShopKeepAPI.swift`: one method per route (~35 methods), `productionBaseURL = https://app-workshop-prod-lwxhu7jxlrbtu.azurewebsites.net`, mixed-response handling per endpoint (`{id}` vs full vs `{success}`), `imageURL(_:userKey:)` appending `?oid=`.
- **`APIClient.postMultipart(path:fields:file:)`** — new: build `multipart/form-data` body (boundary, `file` field with filename+MIME, extra text fields) for image/build-log uploads.
- `CutPlan.swift` port lands here too (Phase 4) so it's unit-testable in the package.

**1.2 App target skeleton** ✅ **CODE DONE (iOS repo, commit `32bbd92`, build 5; builds device+simulator; launches & renders SignInView in the simulator).** As built: `App/` — `WorkshopApp.swift`, `AppModel.swift` (provider-picking init dev-token→Apple→MSAL, `userKey` accessor for `?oid=`, `WORKSHOP_API_BASE`/`WORKSHOP_DEV_TOKEN` overrides, `workshop://project/:id` deep links), `RootView.swift` (dashboard/projects/shaper/shopping/more; iPhone TabView + iPad NavigationSplitView), `Theme.swift`+`Palette.swift` (Workshop cream/rust/ink light+dark from index.css; 5 accent presets rust/forest/slate/amber/navy over shared surfaces; `wsCard`/`creamBackground`/`contentColumn`/`Eyebrow`; system font; `configureAppearance` @MainActor), `AuthImage.swift` (URL/`?oid=` actor cache), `PresentationAnchor.swift`. `Auth/` — MSALAuth (Workshop client/tenant/redirect), AppleAuth+SessionStore+SessionTokenProvider, SignInView (both buttons, no demo mode). Placeholder destination screens; Dashboard does a live `listProjects()`. URL schemes/entitlements/keychain were declared in the Phase 0.3 project.yml.
- ⏳ **STILL PENDING — verify on device (Enzo):** both sign-in flows round-trip to prod `/api/projects`. Simulators can't complete the MSAL broker / Apple flows, so this is the on-device gate before Phase 2 screens. The Dashboard placeholder already renders the real project list once signed in, so it doubles as the round-trip check.

## Phase 2 — Read-only screen parity (enumerate every field from the .tsx first)

Order: cheapest-risk first, each screen greps its React source for the full field/section inventory before coding.
- **2.1 Dashboard** ✅ **DONE (iOS repo `2ab79fd`, build 7; builds clean, needs on-device visual check).** Full port of `Dashboard.tsx`: hero, 4-stat strip (client-computed), search + status filter chips, project card grid, Shaper Hub section, templates (read-only — clone/delete deferred to Phase 3), DIY links. Shared components: `StatusBadge`, `ProjectCard`, `ShaperProjectCard` (all with dark-mode variants). **IA decision:** the web `/` Dashboard is the only list page (no separate projects/shaper routes), so the native tabs are **dashboard / shopping / tables / more** (details push from the Dashboard grids via NavigationLink). ShopKeep companion card deferred (needs the ShopKeep URL/scheme confirmed). ✅ **VERIFIED signed-in (MSAL web sign-in works in the simulator):** real projects load, `?oid=` hero images render, stats/search/filters work, card→detail navigation works. Two device-fixes applied (`1ebbdf6`): (1) `ShaperProject` list rows omit `images`/`cut_list` → custom decoder defaults them to `[]` (NintekKit `c70d854`); (2) card hero needed a bounded box (Rectangle+overlay+clipped) or the title overlapped it; stat labels needed `lineLimit(2, reservesSpace:)` to align.
- **2.2 ProjectDetail** ✅ **DONE & verified signed-in (iOS repo `3ed63b8`, build 11).** Full read-only port of the 1054-line `ProjectDetail.tsx`: hero banner + overlapping meta card (status, title, description, source/OptiCutter links, 4-stat grid), wood/tools chips (`FlowLayout`), sketches + inspiration galleries (PDF tiles → `PDFViewerSheet`/PDFKit), cut list, materials (read + purchased display), finish log, build-log timeline (photos via `?oid=`), linked projects, footer. Fullscreen swipe + pinch-zoom `ImageLightbox`. **Device-fix:** the literal 4-col cut-list table starved its narrow columns (rows ballooned to ~175pt); replaced with a mobile stacked row (part + ×qty / dimensions · material). Writes (edit/delete/toggle/add) deferred to Phase 3.
- **2.3 Shaper detail** ✅ **DONE & verified signed-in (iOS repo `6018b06`, build 13).** Full read-only port of `ShaperProjectDetail.tsx`: photo hero (uploaded image, else `photo_url`), title + CNC badge + "View on Shaper Hub" link, About, Materials, Instructions, Photos gallery (shared `ImageLightbox`), cut list (same mobile stacked-row style as the ProjectDetail fix). Verified on real data ("Assembly Jig" — badge/title/link/About render; Shaper Hub link opens `hub.shapertools.com` correctly). Edit/Delete + cut-plan optimizer deferred to Phase 3/4.
- **2.4 ShoppingList** ✅ **DONE & verified signed-in (iOS repo `363863e`, build 15).** Full port of `ShoppingList.tsx`: unpurchased materials grouped by project, item count + estimated total, "Show purchased" local filter toggle. Purchased checkbox is a read-only indicator (marking purchased is a write, deferred to Phase 3). Verified on real data ("BIRD FEEDER" group, 91 items) + confirmed the show-purchased toggle interaction live.
- **2.5 ConversionTables** ✅ **DONE, mostly verified (iOS repo `363863e`, build 15).** Pure Swift, no API — live mm↔inch converter (3 result pills) + 3 precomputed tables (MM→Inches, Inches→MM, Fractional→MM). Math ported verbatim (gcd-reduced fractions, nearest-1/32). Fractional→MM's 8-column web grid doesn't fit a phone — adapted to whole-inch sections with eighths wrapped as chips (`FlowLayout`), same 384 data points. **Verified:** quick converter hand-checked exact (42mm → 1.65354" → 1 21/32"), MM→Inches table interactive + correct, unit-button wrap bug found and fixed (`millimeters`/`inches` → `mm`/`in`). **Not individually tap-verified:** Inches→MM and Fractional→MM tabs — they share the identical table/row components already proven on MM→Inches, but simulator tap-coordinate targeting got unreliable after a device reboot mid-session; worth a quick on-device glance.
- Per-screen done-criterion: side-by-side with the web page, every field present.

**Phase 2 (read-only screen parity) is now COMPLETE — all 5 screens built.** Next: Phase 3 (write parity).

## Phase 3 — Write parity

- **3.1 ProjectForm** ✅ **CODE DONE (iOS repo `8eff7d5`, build 17).** Full port of the non-AI scope: all fields, status/difficulty pickers, wood/tools tag fields, est. hours stepper. Cut-list + materials row editors use a native `List` with **`.onMove`/`.onDelete` + permanent `.environment(\.editMode, .constant(.active))`** (delete circle + reorder handle always visible, no separate Edit toggle) — persists `sort_order` to every already-saved row after a drag. Row mutation matches the web exactly: add is local-only, remove deletes immediately server-side if the row has an id, Save does per-row create-vs-update sync. Wired: Dashboard toolbar "+" (sheet) and ProjectDetail toolbar pencil (sheet). **Verified in simulator:** sheet presents (create + edit), all fields/pickers/stepper editable, Add Part/Add Material create rows with visible delete+reorder controls, Cancel discards with no server call — **and (later session) `loadExisting()` confirmed against a real project** ("Hand Tool Storage Cabinet": title/URL/description/status/difficulty/tags AND cut-list rows with real fraction dimensions — "Tool Holder 3", "Plane Shelf 1/2 + Trim" — all loaded correctly with working delete+reorder controls). **NOT verified: the actual Save round-trip** (create/update). Tapping Save would write to Enzo's production database, and there's no project-delete UI yet (3.3) to remove test data afterward — deliberately left this for Enzo to test on-device rather than write throwaway data to prod.
- **3.2 Uploads** ✅ **CODE DONE (iOS repo `2d04d53`, build 19; NintekKit `25122d4`).** PhotosPicker (multi-select, re-encodes to JPEG) + `CameraPicker` (lifted from ShopKeepNative, auto-hidden when no camera) + Files/`.fileImporter` (PDF, sketches only) + add-by-URL (inspiration only) + delete (× overlay on thumbnails) → `postMultipart` with **real progress** via a new `URLSessionTaskDelegate` on `APIClient` (NintekKit addition — the plan's "upload task delegate" item). `UploadProgressPanel` floating cards (spinner+%, checkmark, or error+dismiss). **Verified in simulator:** UI renders correctly against real images (existing sketches show with working delete-×), PDF button correctly sketches-only, Camera button correctly absent (no camera in sim). **NOT verified: an actual live upload/add-by-URL/delete round-trip** — simulator tap-targeting was unreliable this session (see memory), and PhotosPicker/camera fundamentally need real media/hardware anyway. This needs Enzo on a real device.
- **3.3 Writes** ✅ **CODE DONE (iOS repo `aaba08d`, build 21; NintekKit `e340c73`).** Materials/purchased optimistic toggles (ProjectDetail + ShoppingList, tap-to-flip + PATCH + revert-on-failure), finish-log add/delete (product/type/color/coats/date/notes form), build-log add (note + PhotosPicker photo, real progress bar)/delete, linked-projects add/remove (project + relationship pickers), templates use/delete (Dashboard), project delete with `confirmationDialog` + save-as-template (toolbar menu). NintekKit's `WSMaterial.purchased`/`ShoppingItem.purchased`/`WSProjectDetail`'s materials-buildLog-finishLog-links arrays changed `let`→`var` to support in-place optimistic mutation. **Verified:** full rebuild clean, NintekKit's 20 tests green after the model changes. **NOT verified: any live write round-trip.** Simulator tap-targeting was unreliable this session (missed text fields and a search bar repeatedly, same issue flagged after the 3.1/3.2 session) — no test data was written (every risky attempt was either blocked by validation or cleanly cancelled). **This whole phase (3.1 Save, 3.2 uploads, 3.3 all of the above) now needs Enzo's on-device pass** — that's the single biggest verification gap in the port so far.
- **3.4 ShaperProjectForm**: create/edit, photo upload/URL override, materials rows, instructions, optional cut-list. *(Not started.)*

## Phase 4 — Cut-plan optimizer (the crown jewel)

- **4.1 Port `cutPlan.ts` → `NintekKit/Sources/NintekKit/CutPlan.swift`** near-verbatim: `parseInches`, `buildCutPieces`, `optimizeCuts` (BSSF + guillotine split + kerf), material/thickness matching. **Unit tests in NintekKit** porting concrete cases (the fraction parser especially: `1' 11½`, `27 3/4`, `.5`, smart quotes) — this is the one piece with real correctness risk.
- **4.2 Optimizer UI** (`CutPlanOptimizer.tsx` spec): stock panel editor (presets 4×8/4×10), kerf input, Generate, stats row, warnings (skipped/unplaced), config save/load via `GET/PUT /api/projects/:id/cut-plan-config` (same JSON shape so web↔native configs interop).
- **4.3 Sheet diagrams** (`CutPlanSheet.tsx` spec): SwiftUI `Canvas` — board rect, colored piece rects (same palette), part-name + fractional-dimension labels with rotate-for-portrait + font auto-fit, color legend.
- **4.4 PDF export**: `ImageRenderer`/UIGraphicsPDFRenderer — one landscape page per sheet → share sheet (replaces the web's print-window SVG doc).

## Phase 5 — AI import, exports, Settings

- **5.1 AI analyze**: ProjectForm "Analyze with AI" → `POST /api/projects/analyze-url` (prefill empty fields, append suggested cut/material rows); ShaperForm → `POST /api/shaper-projects/analyze-url` (+queued image URLs). Handle 503 (no key) + 429 (rate limit) gracefully.
- **5.2 Exports**: cut-list CSV, materials CSV, shopping-list "print" → native PDF/share sheet; Settings "Export JSON backup" (all projects → file).
- **5.3 Settings**: appearance (light/dark/system + accent palette gallery — reuse `PaletteGalleryView` pattern), text size, default status, dashboard sort, show-completed (`@AppStorage`), signed-in identity + sign out, version footer.

## Phase 6 — Native thesis (the point of going native)

- **6.1 Haptics** throughout (`sensoryFeedback`: save success, toggle, optimizer completion).
- **6.2 Widgets** (per Enzo): **In-progress projects** widget + **project stats** widget; App Group snapshot written on data load (ShopKeep `WidgetData` pattern), deep links `workshop://project/<id>`; copy the `NSExtensionPointIdentifier` fix.
- **6.3 App Intents/Shortcuts**: "Add to shopping list" check-off, open project, run optimizer on a project; Spotlight indexing of projects.
- **6.4 Polish round**: adaptive iPad layouts audit (contentColumn caps per screen), pull-to-refresh everywhere, skeleton/loading states, empty states, error toasts.
- **6.5 TestFlight prep**: icon set (`CFBundleIconName` trap), archive/upload, bump to 1.0.0.

## Conventions (from day one)
- **Version bump every commit** (project.yml `MARKETING_VERSION` semver + `CURRENT_PROJECT_VERSION` monotonic; Info.plist references the vars — never literals).
- xcodegen `project.yml` is the only project source; regenerate before every build: `cd "/Users/enzo/repos/Xcode - SwiftUI/Workshop for iOS" && xcodegen generate && xcodebuild -scheme Workshop -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO -clonedSourcePackagesDirPath .spm`
- Every screen: read the `.tsx`, enumerate fields, then build. Behavioral spec notes go in `docs/plans/` as screens are built.
- NintekKit stays dependency-free; MSAL only in the app target behind `TokenProvider`.
- Commit + push per feature (ShopKeepNative-style single-purpose commits); status doc `docs/plans/workshop-native-status.md` maintained as the handoff.

## Verification
- Phase 0: prod `/api/health`; native-shaped Entra token accepted (curl with a real token); Apple exchange mints a session; web app still logs in (regression).
- Phase 1: device sign-in (both providers) → live `/api/projects` list renders.
- Phases 2–3: per-screen side-by-side vs web (same account/data); writes verified by refreshing the web app.
- Phase 4: NintekKit unit tests green (`swift test`); same stock+pieces produce comparable yield to the web optimizer; config saved native loads on web.
- Phase 5: AI import on a real Kreg/Shaper URL; CSV/PDF outputs open correctly.
- Phase 6: widgets update after data change; deep links land on the right screen; TestFlight build validates.
- Enzo device-testing loop after each phase (expect a findings batch like ShopKeep's; budget a fix round).
