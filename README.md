# Workshop for iOS

> [!IMPORTANT]
> **RETIRED - PRESERVATION ONLY as of 2026-08-31.** Workshop for iOS was a
> TestFlight-only, single-user app. Its sole owner/tester now uses the
> [Workshop web app](https://workshop.nintek.com) exclusively, and its
> native-only features were unused. The web app is the canonical, supported
> Workshop client. Do not resume native development, distribution, or App Store
> submission from this repository without a separately approved reactivation.

## Retirement contract

| Fact | Retirement record |
|---|---|
| Final functional main source | `5be546524e79b9c63b2a4effb5ec24e03fe6d777` |
| Final native version/build | `2.3.0 (15)` |
| TestFlight | All 16 uploaded builds, spanning `0.1.0` through `2.3.0`, are expired; internal and external beta states are `EXPIRED` |
| Beta access | The sole internal beta group was emptied and deleted; two tester memberships were removed; app-scoped unlink requests were accepted asynchronously |
| External beta | No external beta group or public link exists |
| App Store record | App `6793709356`; version record `ab8c64ab-bf76-4c14-9b63-ab58630a59db` for `2.2.1` remains `PREPARE_FOR_SUBMISSION` and attached to expired build 13 |
| Review/public release | A historical review submission is `COMPLETE` with its only item `REMOVED` before public release; no current version submission exists, and public App Store lookup returns zero results |
| Supported client | <https://workshop.nintek.com> |

The historical submission must not be rewritten as though it never existed. Its
only item was removed before Workshop was publicly released.

## RETIRED - RESERVED identifiers

The following identifiers preserve Apple ownership, signing and entitlement
continuity, historical App Store records, and compatibility with any retained
installation or account data. **Never delete, transfer, recycle, or repurpose
them for another product.**

- Team `3KB968X34U`
- App `6793709356`
- Version record `ab8c64ab-bf76-4c14-9b63-ab58630a59db`
- Bundle IDs `com.nintek.workshop`, `com.nintek.workshop.widgets`, and
  `com.nintek.workshop.share`

Keep Sign in with Apple, Apple keys, screenshots, metadata, source, tests,
assets, git history, tags, branches, the Xcode project, and signing evidence.
Allow app-specific provisioning profiles to expire naturally; do not revoke
shared certificates or keys. Dormant Apple backend/account compatibility remains
intentionally preserved until a separate approved phase.

## Preservation boundaries

- Treat this repository as a read-only historical record. Do not regenerate the
  Xcode project, advance versions, change runtime configuration, upload another
  build, restore beta access, create a submission, or release the native app.
- Do not change the shared Azure backend or canonical web app as part of native
  retirement. Ongoing Workshop product work belongs in the
  [web repository](https://github.com/EnzoLopez2023/workshop).
- Repository archival or deletion is a separate owner action and is not part of
  this retirement documentation.
- `APP_STORE_STATUS.md` is the retirement authority. Files under `AppStore/`
  preserve historical release evidence; active-sounding steps inside frozen
  evidence are not authorization to execute them.

## Historical source map

| Surface | Preserved authority |
|---|---|
| Targets, versions, signing, generated plists/project | `project.yml` |
| Cross-target visual values | `Shared/LivingPlanTokens.swift` |
| App palette and components | `Workshop/App/Palette.swift`, `Workshop/App/Theme.swift`, `DESIGN.md` |
| Share confirmation | `Shared/ShareConfirmationView.swift` |
| Starter-plan artwork | `Scripts/make-starter-plans.swift` and packaged PNGs |
| App Store retirement state | `APP_STORE_STATUS.md` |
| Provider-scoped account audit | `AppStore/P2-09_PROVIDER_SCOPED_ACCOUNTS.md` |
| Release icons, target variants, screenshots and handoff | `AppStore/RELEASE_VISUAL_MANIFEST.json` |

Workshop was a native SwiftUI woodworking planner sharing the Workshop Azure
backend and Microsoft identity registration with the web client. Apple and
Microsoft sign-in created independent provider-scoped accounts that were never
linked automatically. Notebook remained deferred; Insights was native-only.
These statements describe the frozen implementation, not a roadmap.
