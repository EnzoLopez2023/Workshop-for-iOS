# Workshop App Store readiness

Last source audit: 2026-08-22

This file records Workshop-specific source readiness. Current App Store
Connect, TestFlight, pricing, storefront, and review state remain authoritative
only in the
[portfolio release ledger](https://github.com/EnzoLopez2023/azure-infra/blob/main/RELEASE_LEDGER.md).
The reusable process lives in the
[App Store submission playbook](https://github.com/EnzoLopez2023/azure-infra/blob/main/APP_STORE_SUBMISSION.md).

## Current source

| Fact | Value |
|---|---|
| Marketing version / build | 2.2.1 (12) |
| Bundle | `com.nintek.workshop` |
| Extensions | `com.nintek.workshop.widgets`, `com.nintek.workshop.share` |
| Devices | iPhone and iPad, iOS 17+ |
| Version/project authority | `project.yml` |
| Design authority | `DESIGN.md`, `Shared/LivingPlanTokens.swift` |
| Current App Store screenshots | Five local 6.9-inch iPhone and five local 13-inch iPad candidates; generated outputs are ignored |
| Upload or submission performed here | No |

## Source readiness

- App, widget, and share-extension code use semantic Living Plan Table tokens
  and Apple system typography.
- Sign in with Apple uses Apple's system button; Microsoft uses the official
  four-square mark on a brand-compliant dark plate at equal size.
- More exposes the public Workshop support, privacy, and terms pages.
- No custom font files or font registrations are packaged.
- The seven starter-plan images are original generated runtime assets. Their
  generator uses the current light vellum, spruce, Pencil Blue, and system-type
  direction.
- The app icon contains opaque default, dark, and tinted 1024px renditions.
- The prior marketing compositor and seven stale outputs were removed from the
  working tree and remain recoverable in git history.
- `Scripts/check-shipping-residue.sh` runs before every shipping target build,
  and unit tests inspect both source markers and the built bundle.

## Automated evidence

Verified on iOS 26.5 Simulator on 2026-08-22:

- App, widget-extension, share-extension, and test-bundle builds succeeded from
  the generated Xcode project in Debug and Release.
- The integrated scheme passed 11 tests: 8 unit and 3 UI tests.
- UI tests captured the Settings surface, the exact shared confirmation view
  used by the Share Extension, and a five-screen App Store story. The story also
  passed on a 13-inch iPad simulator.
- The built app contains both embedded extensions and no custom font resource.
- The local listing candidates are five opaque `1320x2868` iPhone JPEGs and five
  opaque `2064x2752` iPad JPEGs, all using synthetic read-only demo data.
- The Release binary contains no `WORKSHOP_API_BASE`, `WORKSHOP_DEV_TOKEN`, or
  other debug launch override; MSAL is exact-pinned at 1.9.0 and NintekKit at
  revision `e425ea6b955c7a1599193fb94a8f0fba1ef16a48`.
- The source cleanup removes 4,046,078 bytes of obsolete screenshot outputs and
  522,191 bytes of font files. Regenerated starter plans shrink from 8,258,517
  to 655,564 bytes while retaining all seven 1600x1100 runtime assets. Including
  retired tooling and documentation, the resulting tracked repository tree is
  12,238,533 bytes smaller than the audited base.

## Remaining release work

- Complete hands-on smoke tests on a physical iPhone and iPad, including
  Microsoft and Apple sign-in, account deletion, camera/photo/PDF paths,
  drag-and-drop, widgets, Live Activities, and the system share sheet.
- Run VoiceOver, largest Dynamic Type, Increased Contrast, Reduce Motion, and
  Reduce Transparency checks on hardware.
- Create and inspect a fresh signed archive/export, then complete TestFlight,
  replace the stale ASC screenshots, and complete draft metadata.
- Verify and publish App Privacy in the signed-in App Store Connect UI.
- Update the public privacy/support release-state copy before any App Review
  submission; it currently and intentionally says the native release is
  withdrawn during rework.
- Upload or submit only after those gates pass.
