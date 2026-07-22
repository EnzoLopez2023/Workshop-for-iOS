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

> **PROGRESS (2026-07-22):** 0.3 ✅ done & committed (`d10f83d`, iOS repo). 0.2 ✅
> code-complete & verified locally, committed on branch **`feat/dual-auth-apple`**
> in the workshop repo — **NOT pushed** (push to main auto-deploys; env must be set
> first). 0.1 ⏳ blocked on Enzo (Azure portal + App Service env). See per-step notes.

**0.1 Pull Entra config** (needs Enzo/az): ~~read `AZURE_TENANT_ID`, `API_AUDIENCE`, `VITE_AZURE_CLIENT_ID`~~ — **the GUIDs are already in the repo** at `.github/workflows/deploy.yml` (`VITE_AZURE_CLIENT_ID: 0f303f8f-207f-4b7f-84a5-b5d0abcf49d1`, `VITE_AZURE_TENANT_ID: 52188f12-db6b-46c6-88ff-08c802f0ed3b`; `API_AUDIENCE` == the client id). No `az` needed for IDs. **Still needs Enzo in the portal:** verify the Entra app registration has **Expose an API** scope (`api://<clientId>/access_as_user`) AND add an **iOS platform redirect** `msauth.com.nintek.workshop://auth` (the two ShopKeep deploy landmines: missing runtime env vars → 503; missing scope → AADSTS500011 login loop). **Plus the new App Service env for 0.2 (below): `SESSION_SECRET`, `APPLE_BUNDLE_ID=com.nintek.workshop` — set these BEFORE merging `feat/dual-auth-apple` to main.**

**0.2 Port dual-auth to `workshop/server.js`** ✅ **DONE (branch `feat/dual-auth-apple`, commit `34297a5`, verified locally, NOT pushed).** As built:
- `ACCEPTED_ISSUERS` (v2.0 + `sts.windows.net/<tenant>/`) + `ACCEPTED_AUDIENCES` (`api://<id>` + bare id) — strict superset of the old single-value check, so no web/Entra regression; fixes the native-token 401.
- Apple path: `APPLE_JWKS`/`APPLE_ISSUER`/`APPLE_AUDIENCES` verify, `POST /api/auth/apple` (id_token → minted HMAC session access+refresh, `apple_<sha256(sub)>` userKey), `POST /api/auth/refresh`, `verifySession`/`mintSession`, `userKeyFromBearer` (own session first, then Entra), `USER_KEY_RE` (GUID or `apple_<64hex>`) gating `getUserDb`+`resolveReadDb`, `upsertProfile`/`readProfile`/`user_profile` table. Gated by `SESSION_SECRET` (`APPLE_AUTH_ENABLED`) → deploys dark, 503s until configured, Entra path unaffected.
- **Empty-seed decision (Enzo, 2026-07-22): new non-primary users get a BLANK schema DB, not a copy of the primary user's data.** Dropped the `copyFileSync(SEED_DB_PATH, …)` in `getUserDb`; the seed snapshot now backs demo mode (`getDemoDb`) only. This closes the exposure that opening Apple sign-in would otherwise create (any Apple ID would have inherited Enzo's real projects). Session names: `SESSION_ISSUER='workshop-api'`, `SESSION_AUDIENCE='workshop-clients'`. Env used: `SESSION_SECRET`, `APPLE_BUNDLE_ID` (native audience), optional `APPLE_WEB_SERVICES_ID` (web, later).
- **Remaining (Enzo):** set App Service env (0.1b) → merge `feat/dual-auth-apple` → main to deploy → verify `/api/health` + a real native token round-trip (**test acceptance, not just rejection** — playbook rule) + web regression.

**0.3 Re-scaffold the Xcode project** ✅ **DONE (iOS repo, commit `d10f83d`).** xcodegen `project.yml` cloned from ShopKeepNative: target `Workshop`, bundle `com.nintek.workshop`, iOS 17, Swift 6, team 3KB968X34U, version 0.1.0/build 1, MSAL+NintekKit. Widgets deferred to Phase 6. `Workshop/App/WorkshopApp.swift` placeholder; builds clean for generic iOS. Dual-auth URL schemes + Apple/App-Group/keychain entitlements declared up front.

## Phase 1 — Foundation (NintekKit + auth + theme + shell)

**1.1 NintekKit additions** (`NintekKit/Sources/NintekKit/`):
- `Models/WorkshopModels.swift`: `WSProject` (list row + detail aggregate), `WSImage`, `CutListItem`, `WSMaterial`, `BuildLogEntry`, `FinishLogEntry`, `ProjectLink`, `WSTemplate`, `ShaperProject`, `ShoppingItem`, `AnalyzeResult`/`ShaperAnalyzeResult`, `CutPlanConfig` (Codable mirror of the web's stock/kerf config JSON). All optionals-heavy, snake_case-decoded; dimensions as `String`.
- `WorkshopAPI.swift` modeled on `ShopKeepAPI.swift`: one method per route (~35 methods), `productionBaseURL = https://app-workshop-prod-lwxhu7jxlrbtu.azurewebsites.net`, mixed-response handling per endpoint (`{id}` vs full vs `{success}`), `imageURL(_:userKey:)` appending `?oid=`.
- **`APIClient.postMultipart(path:fields:file:)`** — new: build `multipart/form-data` body (boundary, `file` field with filename+MIME, extra text fields) for image/build-log uploads.
- `CutPlan.swift` port lands here too (Phase 4) so it's unit-testable in the package.

**1.2 App target skeleton** (`Workshop for iOS/Workshop/`): `App/` — `WorkshopApp.swift`, `AppModel.swift` (provider-picking init: dev token → Apple session → MSAL; `WORKSHOP_API_BASE` override), `RootView.swift` (destinations: **dashboard, projects, shaper, shopping, more** — tune after screens exist), `Theme.swift`+`Palette.swift` with **Workshop token values** (light: cream/rust/ink above; dark: walnut/copper from `[data-theme=dark]`; 5 accent presets as palettes), `AuthImage.swift` (`?oid=` variant). `Auth/` — MSALAuth (new client/tenant/redirect from 0.1), AppleAuth+SessionStore+SessionTokenProvider, SignInView (both buttons; replaces the web Landing page — no demo mode in native).
- MSAL SPM dep, Info.plist URL schemes (`msauth.com.nintek.workshop`, `workshop` for deep links), `LSApplicationQueriesSchemes msauthv2/3`, Sign-in-with-Apple entitlement, keychain group.
- **Verify on device**: both sign-in flows round-trip to prod `/api/projects` before building screens.

## Phase 2 — Read-only screen parity (enumerate every field from the .tsx first)

Order: cheapest-risk first, each screen greps its React source for the full field/section inventory before coding.
- **2.1 Dashboard** (`Dashboard.tsx`): stat strip (In Progress / In Queue / Total Parts / Est. Value — client-computed), search + status filter chips, project card grid (hero image, status badge, wood chips, parts/cost), Shaper CNC section, Templates section (clone/delete deferred to Phase 3), DIY links, ShopKeep companion card (deep link to ShopKeep app if installed, else web).
- **2.2 ProjectDetail** (`ProjectDetail.tsx`, 1054 lines — the parity beast): hero image header, meta card (status, title, description, plans/OptiCutter links, difficulty/hours/parts/cost stat grid), wood/tools chips, Sketches gallery (+PDF tiles → PDFKit viewer), Inspiration gallery, cut-list table, materials list (read + purchased display), finish log, build log timeline (photos via `?oid=`), linked projects. Lightbox → native fullscreen pager.
- **2.3 Shaper list + detail** (`ShaperProjectDetail.tsx`): photo hero, materials, instructions, gallery, cut list.
- **2.4 ShoppingList**: grouped-by-project unpurchased materials, total, show-purchased toggle (write toggle in Phase 3).
- **2.5 ConversionTables**: pure Swift — live mm↔inch converter with nearest-1/32 fractional output + 3 precomputed tables. No API.
- Per-screen done-criterion: side-by-side with the web page, every field present.

## Phase 3 — Write parity

- **3.1 ProjectForm** (`ProjectForm.tsx`): create/edit with all fields, status/difficulty pickers, wood/tools tag editors; cut-list + materials row editors with **List `.onMove` reordering → persist `sort_order` per row** (replaces dnd-kit); per-row create-vs-update sync on save (web pattern).
- **3.2 Uploads**: PhotosPicker + camera + Files (PDF) → `postMultipart` with progress (URLSession upload task delegate); sketch/inspiration kinds; add-by-URL variant; delete image.
- **3.3 Materials/purchased optimistic toggles** (detail + shopping list), finish-log add/edit/delete, build-log add (note+photo)/delete, linked-projects add/remove (relationship picker), templates save-as/clone/delete, project delete with confirm.
- **3.4 ShaperProjectForm**: create/edit, photo upload/URL override, materials rows, instructions, optional cut-list.

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
