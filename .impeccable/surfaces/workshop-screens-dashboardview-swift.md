---
version: 1
slug: "workshop-screens-dashboardview-swift"
primary_target: "Workshop/Screens/DashboardView.swift"
related_targets: ["Workshop/App/RootView.swift","Workshop/Screens/Components/ProjectCard.swift"]
---

# Dashboard

- **Scope and mode:** Operate surface for the signed-in iPhone and iPad dashboard.
- **Audience and job:** An individual DIY woodworker opens Workshop to resume an
  active build, understand its current phase, and reach the next useful action
  before browsing the rest of the project library.
- **Direction:** Living Plan Table. Plans, photos, stages, and actions behave as
  layered tracing sheets on a cool plan surface. Native frosted glass, SF
  typography, the hammer mark, and 14-point squircles replace the Concourse
  Board system completely.
- **Memorable moment:** The active project's plan/photo owns the first viewport
  and a translucent next-action layer appears physically on top of it.
- **Responsive behavior:** iPhone is portrait-only with the native tab bar. iPad
  supports both orientations with a persistent frosted sidebar and a wider
  active-project composition; structure responds to size class, not model.
- **Constraints:** Preserve project navigation, search, status filtering,
  Shaper projects, templates, starter content, shared items, demo mode, refresh,
  deep links, widgets, and all existing backend behavior. No dense metric wall,
  condensed display type, steel bands, tiny radii, or ornamental glass.
