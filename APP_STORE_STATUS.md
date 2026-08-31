# Workshop App Store retirement status

Retirement recorded: **2026-08-31**

> [!IMPORTANT]
> **RETIRED - PRESERVATION ONLY.** Workshop for iOS was available only through
> TestFlight and had one owner/tester. The owner uses
> <https://workshop.nintek.com> exclusively, and native-only features were
> unused. The web app is the canonical, supported Workshop client. There is no
> remaining native release work. After this final documentation merges, the
> GitHub repository is intentionally archived as a readable, reversible,
> read-only preservation action.

## Retirement authority

| Fact | Final state |
|---|---|
| Final functional main source before retirement docs | `5be546524e79b9c63b2a4effb5ec24e03fe6d777` |
| Final native version/build | `2.3.0 (15)` |
| Bundle | `com.nintek.workshop` |
| Extensions | `com.nintek.workshop.widgets`, `com.nintek.workshop.share` |
| Devices | iPhone and iPad, iOS 17+ |
| Version/project authority | Preserved `project.yml` |
| Design authority | Preserved `DESIGN.md` and `Shared/LivingPlanTokens.swift` |
| Supported client | <https://workshop.nintek.com> |

The retirement documents are the first nonfunctional changes after the final
functional main source. No Swift source, tests, project configuration, generated
Xcode files, assets, screenshots, evidence payloads, or runtime configuration
are part of retirement.

## Phase 2 through 4 record

| Phase | Result |
|---|---|
| Phase 2 - TestFlight distribution retirement | All TestFlight builds and beta access were retired; no public release remains |
| Phase 3 - RETIRED - RESERVED | Apple identifiers, capabilities, records, metadata, and signing evidence remain reserved and must never be reused |
| Phase 4 - final docs and GitHub archival | This final contract lands, then the GitHub repository is archived as a reversible read-only state; it remains readable, is never deleted, and is unarchived only under separately approved reactivation |
| Scheduled automation | No `.github/workflows` directory, GitHub Actions workflow, project workflow, or session automation exists; no automatic release trigger required a workflow commit |

## App Store Connect and TestFlight state at retirement

| Resource | Retirement state |
|---|---|
| Team | `3KB968X34U` |
| App | `6793709356`, primary name `Nintek Workshop` |
| Version record | `ab8c64ab-bf76-4c14-9b63-ab58630a59db`, version `2.2.1`, remains `PREPARE_FOR_SUBMISSION` and attached to expired build 13 |
| TestFlight inventory | All 16 uploaded Workshop builds across versions `0.1.0` through `2.3.0` are expired; every internal and external beta state is `EXPIRED` |
| Internal beta access | The sole internal beta group was emptied and deleted; two tester memberships were removed; app-scoped unlink requests were accepted asynchronously |
| External beta access | No external beta group or public link exists |
| Capabilities | `APPLE_ID_AUTH` and `APP_GROUPS` remain retained |
| Provisioning profiles | Zero team provisioning profiles at the retirement audit |
| Distribution certificate | No active distribution certificate at the retirement audit |
| Historical review | A historical review submission is `COMPLETE`; its only item is `REMOVED` |
| Current submission | No current version submission exists |
| Public release | Workshop was never publicly released; public App Store lookup returns zero results |

The historical review submission must remain in the record. Its only item was
removed before public release; retirement does **not** mean that no historical
submission ever existed.

## RETIRED - RESERVED

These identifiers must never be deleted, transferred, recycled, or repurposed:

| Identifier | Preservation reason |
|---|---|
| Team `3KB968X34U` | Preserves the Apple ownership and signing namespace; shared team certificates and keys support other apps |
| App `6793709356` | Preserves the historical App Store container and prevents identity confusion |
| Version record `ab8c64ab-bf76-4c14-9b63-ab58630a59db` | Preserves the draft, build attachment, metadata, and review history |
| `com.nintek.workshop` | Preserves the native app's signing, entitlement, keychain, and retained-install identity |
| `com.nintek.workshop.widgets` | Preserves the widget extension identity and entitlement continuity |
| `com.nintek.workshop.share` | Preserves the share extension identity and entitlement continuity |

## Preservation contract

- Do not create an Xcode archive, export or upload another build, restore beta
  access, change the version record, create a submission, or release the app.
- Do not remove Sign in with Apple capability, Apple keys, screenshots,
  metadata, source, tests, assets, history, tags, branches, the Xcode project,
  or signing evidence.
- Allow app-specific provisioning profiles to expire naturally. Do not revoke
  shared certificates or keys.
- Preserve dormant Apple backend/account compatibility until a separate phase is
  explicitly approved. Retirement does not authorize backend or account cleanup.
- Do not alter the canonical web client or shared Azure backend as part of this
  native retirement.
- Archive the GitHub repository immediately after this final retirement change
  merges. Keep it readable and read-only; never delete it. Unarchive only under
  separately approved native reactivation.
- Treat active-sounding steps in preserved release evidence as historical gates,
  not current instructions.

The reusable
[App Store submission playbook](https://github.com/EnzoLopez2023/azure-infra/blob/main/APP_STORE_SUBMISSION.md)
remains a cross-app reference only. It is not authorization to submit Workshop.

## Preserved build 13 release evidence

The following sections preserve the 2026-08-23 evidence for Workshop `2.2.1
(13)`, source `c3e6aab6b8fe081d5b9eee9781bd59378e0ed07a`. They predate final
functional source `5be546524e79b9c63b2a4effb5ec24e03fe6d777` and do not describe
an active candidate.

### Source-readiness evidence

- App, widget, and share-extension code used semantic Living Plan Table tokens
  and Apple system typography.
- Sign in with Apple used Apple's system button; Microsoft used the official
  four-square mark on a brand-compliant dark plate at equal size.
- More exposed the public Workshop support, privacy, and terms pages.
- Apple and Microsoft sign-in disclosed separate unlinked workspaces; More named
  the active provider and scoped deletion/recreation copy to that workspace.
- No custom font files or font registrations were packaged.
- The seven starter-plan images were original generated runtime assets using the
  light vellum, spruce, Pencil Blue, and system-type direction.
- The app icon contained opaque default, dark, and tinted 1024px renditions.
- The prior marketing compositor and seven stale outputs remained recoverable in
  git history.
- `Scripts/check-shipping-residue.sh` ran before every shipping target build,
  and unit tests inspected both source markers and the built bundle.

### Historical Impeccable native audit

| Dimension | Score | Result at audit |
|---|---:|---|
| Accessibility | 3/4 | Source labels, Dynamic Type, Reduce Motion, and Reduce Transparency paths were present; final hardware passes remained |
| Performance | 4/4 | Lazy/native containers, bounded image handling, and no launch-blocking work found |
| Appearance and theming | 4/4 | Living Plan Table tokens, dark/light assets, opaque icon renditions, and extension adaptations |
| Platform conformance | 4/4 | Native tabs/split view, system Apple sign-in button, SF Symbols, sheets, and controls |
| Adaptivity | 3/4 | Portrait iPhone and portrait iPad sets passed; physical iPad rotation/multitasking remained |
| **Total** | **18/20** | **Excellent; native conformance pass** |

The release pass corrected the iPad hero-title occlusion and action-layer
contrast, compact hero status overlap, Apple/Microsoft sign-in treatment, retired
accent color, tinted icon polarity, and lead hero scrim.

### Historical automated evidence

Verified on iOS 26.5 Simulator on 2026-08-23:

- App, widget-extension, share-extension, and test-bundle builds succeeded from
  the generated Xcode project in Debug and Release.
- The integrated scheme passed 24 tests: 16 unit and 8 UI tests.
- UI tests captured the Settings surface, the shared Share Extension
  confirmation view, and a five-screen App Store story. The story also passed on
  a 13-inch iPad simulator.
- The built app contained both embedded extensions and no custom font resource.
- Listing candidates were five opaque `1320x2868` iPhone JPEGs and five opaque
  `2064x2752` iPad JPEGs using synthetic read-only demo data.
- The Release binary contained no `WORKSHOP_API_BASE`, `WORKSHOP_DEV_TOKEN`, or
  other debug launch override; MSAL was exact-pinned at 1.9.0 and NintekKit at
  revision `e425ea6b955c7a1599193fb94a8f0fba1ef16a48`.
- A signed archive was created at `2026-08-23T15:24:20Z`. The exported Apple
  Distribution IPA was 8,658,906 bytes with SHA-256
  `61410660f2dc9490ad12e22e02bd90998888848c03c96bff1d69398fdc1b18cd`;
  Apple's pre-upload validation returned no errors.
- The app, widget, and share extension exported as arm64, version `2.2.1 (13)`,
  with `get-task-allow=false`, the expected App Group, Sign in with Apple and
  Keychain entitlements, `ITSAppUsesNonExemptEncryption=false`, and no secret
  files.
- App, widget, share, MSAL, and package privacy manifests were present. App,
  widget, share, and MSAL dSYM UUIDs matched their archived binaries.
- Endpoint inspection found the production Workshop API, Microsoft identity,
  user-facing plan/support links, and intentional `workshop-demo.invalid`
  local-demo data. The pinned NintekKit binary also retained an unreachable
  ShopKeep endpoint/Cairn resource bundle; no Workshop path called them, and no
  secret or debug endpoint override shipped.
- Source cleanup removed 4,046,078 bytes of obsolete screenshot outputs and
  522,191 bytes of font files. Regenerated starter plans shrank from 8,258,517 to
  655,564 bytes while retaining all seven 1600x1100 runtime assets. Including
  retired tooling and documentation, the tracked tree became 12,238,533 bytes
  smaller than the audited base.

### Historical App Store record evidence

| Resource | Preserved evidence |
|---|---|
| Version | `ab8c64ab-bf76-4c14-9b63-ab58630a59db`, `2.2.1`, `PREPARE_FOR_SUBMISSION`, `AFTER_APPROVAL`; still attached to expired build 13 |
| Build 13 | `d8a3bc9c-22c3-4f16-98d4-66683edca97a`; historically `VALID`, `APP_STORE_ELIGIBLE`, attached, and internal `IN_BETA_TESTING`; now expired |
| Build 12 | `363cc8ef-641d-451e-9ae7-5f0542ff5700`; historically valid, detached, and non-submittable; now expired |
| iPhone screenshots | Set `918e928d-f1df-4b86-80f7-7a20be86df98`, five ordered build-13 `1320x2868` assets, all `COMPLETE`; prior build-12 assets were deleted |
| iPad screenshots | Set `81034025-b164-44b2-a8e2-eafbcc1b1267`, five ordered build-13 `2064x2752` assets, all `COMPLETE`; prior build-12 assets were deleted |
| Metadata | Shaper Hub, Tables, Insights, Dynamic Type/themes, support URL, keywords, free/no-IAP facts, and provider-scoped reviewer notes |
| Commercial | USA base price `0.0`, 174 automatic zero-price points, and zero IAPs/subscriptions; preserved |
| Availability | 175 territories and new-territory opt-in; preserved |
| Review | The 2026-08-23 pass created no new review resources; the retirement audit records the older completed submission and removed item above |

Historical public URLs are privacy
<https://www.nintek.com/workshop/privacy>, support
<https://www.nintek.com/workshop/support>, marketing
<https://www.nintek.com/workshop>, and terms
<https://www.nintek.com/terms>.

`AppStore/RELEASE_VISUAL_MANIFEST.json` remains the immutable authority for the
final icon, target variants, screenshots, App Store Connect assets, capture
commands, release source, Concourse-residue result, and nintek/social handoff
evidence.

## No remaining release work

Former hardware QA, App Privacy publication, reviewer-account preparation,
Guideline 2.1 recording, EU trader, public support-copy, metadata, naming, and
submission gates are intentionally abandoned release work. Preserve their
evidence; do not complete or use them to submit the retired app.
