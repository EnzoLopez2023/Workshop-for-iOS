# Product

<!-- impeccable:product-schema 1 -->

> [!IMPORTANT]
> **RETIRED - PRESERVATION ONLY as of 2026-08-31.** Workshop for iOS was a
> TestFlight-only, single-user client. The sole owner/tester uses
> <https://workshop.nintek.com> exclusively, and the native-only features were
> unused. The web app is now the canonical, supported Workshop product. The
> remaining document is a frozen product snapshot, not an active roadmap.

## Retirement Contract

| Fact | Retirement record |
|---|---|
| Final functional main source | `5be546524e79b9c63b2a4effb5ec24e03fe6d777` |
| Final native version/build | `2.3.0 (15)` |
| TestFlight | All 16 uploaded builds across `0.1.0` through `2.3.0` expired with internal and external beta states `EXPIRED` |
| Beta access | Sole internal group emptied and deleted; two tester memberships removed; app-scoped unlink requests accepted asynchronously |
| External beta | No external group or public link exists |
| App Store | App `6793709356`; `2.2.1` record `ab8c64ab-bf76-4c14-9b63-ab58630a59db` remains `PREPARE_FOR_SUBMISSION` and attached to expired build 13 |
| Review/public release | Historical submission `COMPLETE`, only item `REMOVED` before public release; no current version submission; public lookup returns zero results |

The historical submission existed and must remain part of the record; its only
item was removed before Workshop became public.

## RETIRED - RESERVED

Team `3KB968X34U`, app `6793709356`, version record
`ab8c64ab-bf76-4c14-9b63-ab58630a59db`, and bundle IDs
`com.nintek.workshop`, `com.nintek.workshop.widgets`, and
`com.nintek.workshop.share` must never be deleted, transferred, recycled, or
repurposed. They preserve product identity, signing and entitlement continuity,
historical records, and compatibility with retained installations or dormant
accounts.

Preserve Sign in with Apple, Apple keys, metadata, screenshots, source, tests,
assets, history, tags, branches, the Xcode project, and signing evidence.
App-specific provisioning profiles should expire naturally; shared certificates
and keys must not be revoked. Dormant Apple backend/account compatibility stays
in place until a separate approved phase. Native development, redesign,
distribution, submission, and release are no longer product work.

## Platform

ios

## Historical Users

Workshop primarily serves individual DIY woodworkers planning and completing
projects in a home workshop. They use the app while researching ideas, preparing
materials and cuts, shopping, and documenting work in progress.

## Historical Product Purpose

Workshop provides one continuous workflow from an initial idea and plan through
materials, cut lists, shopping, execution, and build records. Success means a
woodworker can understand what a project needs, prepare it, build it, and retain
the resulting knowledge without splitting the work across unrelated tools.

## Historical Positioning

Workshop is a woodworking-specific project system rather than a generic task
manager. Each project joins plans, wood and tools, parts and optimized cuts,
materials and purchases, finish records, build notes, photos, related projects,
CNC/Shaper work, and public 3D-model references in one durable record.

## Frozen Operating Context

- The preserved iOS app and the Workshop web app shared the same Azure backend
  and supported full bidirectional CRUD.
- iPhone is a portrait-only experience.
- iPad supports portrait and landscape, including responsive sidebar and
  multi-column layouts where the available width supports them.
- The app is used both away from the shop for planning and purchasing and in the
  workshop while measuring, cutting, assembling, finishing, and documenting.

## Frozen Capabilities and Constraints

- The native SwiftUI application targeted iOS 17.
- Dashboard, project detail and editing, shopping, conversion tables, cut
  planning, Shaper/CNC projects, Bambu Hub imports from public MakerWorld,
  Thingiverse, and Printables pages, insights, settings, sharing, widgets, Live
  Activities, Spotlight, deep links, Handoff, and photo/PDF workflows are
  existing product capabilities.
- Notebook is deferred to v2; Insights is native-only.
- Microsoft Entra and Sign in with Apple authentication retained the frozen
  shared-backend identity contract. They are independent provider-scoped
  Workshop accounts: the same email can have separate Apple and Microsoft
  workspaces, no automatic linking or merge occurs, and deletion affects only
  the currently authenticated provider identity.
- Official Thingiverse API tokens are write-only account connections: they are
  encrypted by the backend, never returned, and never persisted by the iOS app.
  Workshop never collects MakerWorld credentials or cookies; protected
  MakerWorld originals are downloaded by the user and added as local files.
- No native API or schema evolution is planned. Ongoing compatibility and
  product work belong to the Workshop web client.
- The frozen cut-plan optimizer preserved exact-layout parity with the web
  implementation through NintekKit at the final functional source.
- No native redesign or feature expansion is planned. Existing source and design
  evidence remain preserved as shipped.

## Historical Brand Commitments

The product name is Workshop and it remains part of the Nintek app family. The
hammer mark remains recognizable through visual redesigns. Its language should
be practical, direct, and grounded in real woodworking tasks. The current
Living Plan Table system is the shipping visual direction: native system type,
cool vellum surfaces, spruce drawing ink, and restrained drafting annotations.

## Preserved Evidence

- The production SwiftUI implementation and its shared backend contract.
- Real project, material, cut-list, shopping, finish-log, build-log, image, PDF,
  Shaper, and imported 3D-project data models.
- Bundled demo content and starter projects for realistic empty, populated, and
  read-only states.
- Current simulator and physical-device captures of the shipping app; archived
  marketing screenshots are historical evidence only.
- No testimonials, performance claims, or external proof should be invented.

## Historical Product Principles

1. Keep the whole build connected from idea through completion.
2. Preserve the woodworker's place and context across navigation and device
   changes.
3. Make project-critical information legible and actionable in workshop
   conditions.
4. Prefer familiar iOS behavior over custom interaction for its own sake.
5. Keep native and web data behavior in parity.

## Historical Accessibility & Inclusion

The preserved implementation was designed for Dynamic Type, VoiceOver labeling,
minimum 44-point touch targets, sufficient contrast, dark-mode support,
reduced-motion behavior, and state communication that did not rely on color
alone.
