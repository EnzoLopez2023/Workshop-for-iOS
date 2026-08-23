# Workshop App Store readiness

Last source audit: 2026-08-23

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
| Release source | `a6d80030d9ee3c0f1c96dcc02883710de6215d54` |
| Current App Store screenshots | Five `APP_IPHONE_67` and five `APP_IPAD_PRO_3GEN_129` assets, all `COMPLETE` |
| Upload or submission performed here | Build 12 uploaded and `VALID` in internal TestFlight; no App Review submission or public release |

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

## Impeccable native audit

| Dimension | Score | Result |
|---|---:|---|
| Accessibility | 3/4 | Source labels, Dynamic Type, Reduce Motion, and Reduce Transparency paths are present; final hardware passes remain |
| Performance | 4/4 | Lazy/native containers, bounded image handling, and no launch-blocking work found |
| Appearance and theming | 4/4 | Living Plan Table tokens, dark/light assets, opaque icon renditions, and current extension adaptations |
| Platform conformance | 4/4 | Native tabs/split view, system Apple sign-in button, SF Symbols, sheets, and controls |
| Adaptivity | 3/4 | Current portrait iPhone and portrait iPad sets pass; physical iPad rotation/multitasking remains |
| **Total** | **18/20** | **Excellent; native conformance pass** |

The release pass corrected the iPad hero-title occlusion and action-layer
contrast, the compact hero status overlap, Apple/Microsoft sign-in treatment,
the retired accent color, and the tinted icon polarity.

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
- A signed archive was created at `2026-08-22T21:02:17Z`. The exported
  Apple Distribution IPA is 8,637,347 bytes with SHA-256
  `214338c3afbf8a5c64a0f243b0eea0a79235eba7a115705a1a95f553ecce2296`;
  Apple's pre-upload validation returned no errors.
- The app, widget, and share extension export as arm64, version `2.2.1 (12)`,
  with `get-task-allow=false`, the expected App Group, Sign in with Apple and
  Keychain entitlements, `ITSAppUsesNonExemptEncryption=false`, and no secret
  files.
- App, widget, share, MSAL, and package privacy manifests are present. App,
  widget, share, and MSAL dSYM UUIDs match their archived binaries.
- Endpoint inspection found the production Workshop API, Microsoft identity,
  the user-facing plan/support links, and intentional `workshop-demo.invalid`
  local-demo data. The monolithic pinned NintekKit binary also retains an
  unreachable ShopKeep endpoint/Cairn resource bundle; no Workshop path calls
  them and no secret or debug endpoint override ships.
- The source cleanup removes 4,046,078 bytes of obsolete screenshot outputs and
  522,191 bytes of font files. Regenerated starter plans shrink from 8,258,517
  to 655,564 bytes while retaining all seven 1600x1100 runtime assets. Including
  retired tooling and documentation, the resulting tracked repository tree is
  12,238,533 bytes smaller than the audited base.

## App Store Connect and TestFlight

| Resource | State |
|---|---|
| App | `6793709356`, primary name `Nintek Workshop` (`Workshop` was unavailable) |
| Version | `ab8c64ab-bf76-4c14-9b63-ab58630a59db`, `2.2.1`, `PREPARE_FOR_SUBMISSION`, `AFTER_APPROVAL` |
| Build | `363cc8ef-641d-451e-9ae7-5f0542ff5700`, build 12, `VALID`, `APP_STORE_ELIGIBLE`, internal `IN_BETA_TESTING` |
| iPhone screenshots | Set `918e928d-f1df-4b86-80f7-7a20be86df98`, five ordered `1320x2868` assets, all `COMPLETE` |
| iPad screenshots | Set `81034025-b164-44b2-a8e2-eafbcc1b1267`, five ordered `2064x2752` assets, all `COMPLETE`; three stale title-art assets deleted |
| Metadata | Current Shaper Hub, Tables, Insights, Dynamic Type/themes, support URL, keywords, and no-IAP/free review notes |
| Commercial | Existing USA base price `0.0`, 174 automatic zero-price points, zero IAPs/subscriptions; not mutated |
| Availability | Existing 175 territories available and new-territory opt-in; not mutated |
| Review | No new `reviewSubmission`, item, or `appStoreVersionSubmission` |

Public URLs are privacy
`https://www.nintek.com/workshop/privacy`, support
`https://www.nintek.com/workshop/support`, marketing
`https://www.nintek.com/workshop`, and terms
`https://www.nintek.com/terms`.

## Remaining release work

- **P2-09 next-build blocker:** build 12 implements separate Apple and
  Microsoft/Entra identities correctly, but its sign-in screen does not disclose
  that the providers create separate unlinked workspaces, More -> Account does
  not name the active provider, and deletion copy does not explicitly limit
  deletion to the current provider-scoped Workshop account. Do not submit build
  12 for App Review. Implement and verify the exact copy/test contract in
  `AppStore/P2-09_PROVIDER_SCOPED_ACCOUNTS.md`, increment the build, and replace
  build 12 only after the successor is `VALID`.
- Correct the public Workshop Support deletion path from the stale
  `Settings -> Account & Data` wording to the shipped `More -> Account` path
  while preserving its accurate provider-scoped deletion explanation.
- Complete hands-on smoke tests on a physical iPhone and iPad, including
  Microsoft and Apple sign-in, account deletion, camera/photo/PDF paths,
  drag-and-drop, widgets, Live Activities, and the system share sheet.
- Run VoiceOver, largest Dynamic Type, Increased Contrast, Reduce Motion, and
  Reduce Transparency checks on hardware.
- Verify and publish App Privacy in the signed-in App Store Connect UI.
- Create, seed, and clean-device verify the protected reviewer account described
  in `AppStore/REVIEWER_ACCOUNT_CHECKLIST.md`.
- Record the exact TestFlight build on current physical iPhone and iPad hardware
  and complete every placeholder in `AppStore/GUIDELINE_2_1_TEMPLATE.txt`.
- Complete EU trader status for the 27 affected territories in App Store
  Connect, or deliberately remove those territories before review.
- Update the public privacy/support release-state copy before any App Review
  submission; it currently and intentionally says the native release is
  withdrawn during rework.
- Confirm `USES_THIRD_PARTY_CONTENT` remains the intended declaration for
  user-submitted plan links even though bundled art is original.
- Keep the `Nintek Workshop` fallback name or pursue the separate ownership path
  for `Workshop`.
- Synchronize this verified state into the cross-repo release ledger.
- Do not create or submit App Review until all external gates pass.
