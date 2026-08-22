# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Workshop primarily serves individual DIY woodworkers planning and completing
projects in a home workshop. They use the app while researching ideas, preparing
materials and cuts, shopping, and documenting work in progress.

## Product Purpose

Workshop provides one continuous workflow from an initial idea and plan through
materials, cut lists, shopping, execution, and build records. Success means a
woodworker can understand what a project needs, prepare it, build it, and retain
the resulting knowledge without splitting the work across unrelated tools.

## Positioning

Workshop is a woodworking-specific project system rather than a generic task
manager. Each project joins plans, wood and tools, parts and optimized cuts,
materials and purchases, finish records, build notes, photos, related projects,
and CNC/Shaper work in one durable record.

## Operating Context

- The iOS app and the Workshop web app share the same Azure backend and support
  full bidirectional CRUD.
- iPhone is a portrait-only experience.
- iPad supports portrait and landscape, including responsive sidebar and
  multi-column layouts where the available width supports them.
- The app is used both away from the shop for planning and purchasing and in the
  workshop while measuring, cutting, assembling, finishing, and documenting.

## Capabilities and Constraints

- Native SwiftUI application targeting iOS 17.
- Dashboard, project detail and editing, shopping, conversion tables, cut
  planning, Shaper/CNC projects, insights, settings, sharing, widgets, Live
  Activities, Spotlight, deep links, Handoff, and photo/PDF workflows are
  existing product capabilities.
- Notebook is deferred to v2; Insights is native-only.
- Microsoft Entra and Sign in with Apple authentication must retain the current
  shared-backend identity contract.
- API and schema changes must remain compatible with the Workshop web client.
- The cut-plan optimizer must preserve exact layout parity with the web
  implementation through NintekKit.
- The redesign must preserve existing workflows and data semantics. It may
  replace navigation presentation, visual hierarchy, typography, color,
  component styling, and responsive composition.

## Brand Commitments

The product name is Workshop and it remains part of the Nintek app family. The
hammer mark remains recognizable through visual redesigns. Its language should
be practical, direct, and grounded in real woodworking tasks. The current
Living Plan Table system is the shipping visual direction: native system type,
cool vellum surfaces, spruce drawing ink, and restrained drafting annotations.

## Evidence on Hand

- The production SwiftUI implementation and its shared backend contract.
- Real project, material, cut-list, shopping, finish-log, build-log, image, PDF,
  and Shaper data models.
- Bundled demo content and starter projects for realistic empty, populated, and
  read-only states.
- Current simulator and physical-device captures of the shipping app; archived
  marketing screenshots are historical evidence only.
- No testimonials, performance claims, or external proof should be invented.

## Product Principles

1. Keep the whole build connected from idea through completion.
2. Preserve the woodworker's place and context across navigation and device
   changes.
3. Make project-critical information legible and actionable in workshop
   conditions.
4. Prefer familiar iOS behavior over custom interaction for its own sake.
5. Keep native and web data behavior in parity.

## Accessibility & Inclusion

The redesign must preserve Dynamic Type, VoiceOver labeling, minimum 44-point
touch targets, sufficient contrast, dark-mode support, reduced-motion behavior,
and clear state communication that does not rely on color alone.
