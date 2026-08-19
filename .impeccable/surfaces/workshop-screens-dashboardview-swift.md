---
version: 1
slug: "workshop-screens-dashboardview-swift"
primary_target: "Workshop/Screens/DashboardView.swift"
related_targets: ["Workshop/App/RootView.swift","Workshop/Screens/Components/ProjectCard.swift"]
---

# Dashboard

- **Scope and mode:** Operate surface for the signed-in iPhone and iPad dashboard.
- **Audience and job:** An individual DIY woodworker opens Workshop to resume an
  active build or reach a Shaper/CNC project without searching through one long
  mixed project feed.
- **Direction:** Living Plan Table. Plans, photos, stages, and actions behave as
  layered tracing sheets on a cool plan surface. Native frosted glass, SF
  typography, the hammer mark, and 14-point squircles replace the Concourse
  Board system completely.
- **Memorable moment:** The active project's plan/photo owns the first viewport
  and a translucent next-action layer appears physically on top of it.
- **Navigation model:** One Dashboard destination and one `NavigationStack`.
  A persistent native segmented switcher in a frosted safe-area inset directly
  below navigation owns project type. **Projects** contains the active-build
  layer, its own search, status filter, regular library, templates, and
  inspiration. **Shaper Hub** opens with its own contextual search followed
  immediately by the separate Shaper/CNC library, dedicated count, empty, and
  no-results states, with no hero or regular-project status controls.
- **Creation:** The top add control is always a native menu with **New Project**
  and **New Shaper Hub Project**; each option selects its matching page before
  presenting the existing form.
- **State and routing:** Persist the selected page with scene storage. Keep
  Projects search, Shaper Hub search, and Projects-only status filtering
  independent. Project deep links, shared-item intake, and regular creation
  select Projects; Shaper routes and creation select Shaper Hub. Both project
  types push through the same path so returning preserves dashboard context.
- **Responsive behavior:** iPhone is portrait-only with the native tab bar. iPad
  supports both orientations with a persistent frosted sidebar and a wider
  active-project composition. All three device/orientation cases use the same
  dashboard page model; structure responds to size class, not model.
- **Constraints:** Preserve independent search/filter state when switching,
  project navigation, templates, starter content, shared items, demo mode,
  refresh, deep links, widgets, and all existing backend behavior. Do not
  duplicate project type in the status filter or introduce a second navigation
  stack, top-level tab, mixed-type grid, dense metric wall, or ornamental glass.
