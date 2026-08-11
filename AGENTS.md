# AGENTS.md — Workshop-for-iOS

Native SwiftUI Workshop (woodworking project planner). Bundle `com.nintek.workshop`, iOS 17, XcodeGen, scheme `Workshop`.

## Start here
- **Cross-app standards:** https://github.com/EnzoLopez2023/azure-infra/blob/main/STANDARDS.md
- **Cross-repo product map:** https://github.com/EnzoLopez2023/azure-infra/blob/main/PORTFOLIO.md

> Agent sessions run in git worktrees, so relative paths into sibling repos (`../foo/BAR.md`) do **not** resolve. The cross-repo facts below are inlined deliberately. Always link other repos by absolute GitHub URL.

## Scope

10 of the web app's 12 routes are implemented. **Notebook is deferred to v2.** `InsightsView` is **native-only**.

## Related surfaces

### [workshop](https://github.com/EnzoLopez2023/workshop) — React web app
**PORT** sharing the **same Azure backend and Entra registration**; full bidirectional CRUD.

### [NintekKit](https://github.com/EnzoLopez2023/NintekKit) — shared Swift package
Consumed by this app, and home of the cut-plan optimiser (`CutPlan.swift`). A breaking change there also hits CairnNative, ShopKeepNative and Tare-for-iOS.

## Propagation rule

**BACKEND + ALGORITHM PARITY.**

1. **API / schema changes go to both clients.** The backend is shared, so a one-sided change breaks the web app silently.
2. **The cut-plan optimiser is duplicated.** NintekKit's `CutPlan.swift` is a direct port of the web app's `src/lib/cutPlan.ts` and is **unit-tested for exact-match layouts**.

   **Change one, change the other, re-run the parity tests.**

## Microsoft identity

- MSAL uses the `common` authority so the Workshop registration can accept any
  Entra tenant and personal Microsoft accounts.
- Preserve existing Nintek storage keys: the home tenant
  `52188f12-db6b-46c6-88ff-08c802f0ed3b` uses bare `oid`.
- Every external principal uses lowercase `<tid>_<oid>`. Keep this algorithm
  identical to the Workshop backend whenever identity handling changes.
- The Entra registration must support
  `AzureADandPersonalMicrosoftAccount`, issue v2 access tokens, expose
  `access_as_user`, and retain `msauth.com.nintek.workshop://auth`.
