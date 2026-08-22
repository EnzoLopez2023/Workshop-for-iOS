# Workshop for iOS

Workshop is a native SwiftUI planner for woodworking projects. It shares the
Workshop Azure backend and Microsoft identity registration with the
[web client](https://github.com/EnzoLopez2023/workshop).

## Source of truth

| Surface | Authority |
|---|---|
| Targets, versions, signing, generated plists/project | `project.yml` |
| Cross-target visual values | `Shared/LivingPlanTokens.swift` |
| App palette and components | `Workshop/App/Palette.swift`, `Workshop/App/Theme.swift`, `DESIGN.md` |
| Share confirmation | `Shared/ShareConfirmationView.swift` |
| Starter-plan artwork | `Scripts/make-starter-plans.swift` and packaged PNGs |
| App Store readiness | `APP_STORE_STATUS.md` and the [shared submission playbook](https://github.com/EnzoLopez2023/azure-infra/blob/main/APP_STORE_SUBMISSION.md) |

The app, widgets, and share extension use Apple system fonts. The build-time
shipping-residue check rejects retired font resources, palette values, and
visual-system identifiers.

## Build and test

```sh
xcodegen generate
xcodebuild -project Workshop.xcodeproj -scheme Workshop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
xcodebuild -project Workshop.xcodeproj -scheme Workshop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test
```

Notebook remains deferred to v2. Insights is native-only. API/schema changes
must remain compatible with the web client, and cut-plan algorithm changes must
remain exact-layout compatible with
[NintekKit](https://github.com/EnzoLopez2023/NintekKit).
