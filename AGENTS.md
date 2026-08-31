# AGENTS.md - Workshop-for-iOS

> [!IMPORTANT]
> **RETIREMENT CONTRACT - TAKES PRECEDENCE.** This repository is
> preservation-only as of **2026-08-31**. The native app was TestFlight-only,
> had one owner/tester, was displaced by exclusive use of the web client, and
> had unused native-only features. The canonical supported client is
> <https://workshop.nintek.com>. Do not make product, runtime, release, or
> App Store changes here without separately approved reactivation.

## Authoritative retirement record

| Fact | Value |
|---|---|
| Final functional main source | `5be546524e79b9c63b2a4effb5ec24e03fe6d777` |
| Final native version/build | `2.3.0 (15)` |
| TestFlight | All 16 uploaded builds from `0.1.0` through `2.3.0` are expired; internal and external beta states are `EXPIRED` |
| Beta cleanup | Sole internal beta group emptied and deleted; two tester memberships removed; app-scoped unlink requests accepted asynchronously |
| External beta | No external beta group or public link exists |
| Draft record | App `6793709356`; version record `ab8c64ab-bf76-4c14-9b63-ab58630a59db` for `2.2.1` remains `PREPARE_FOR_SUBMISSION` and attached to expired build 13 |
| Review/public state | Historical review submission `COMPLETE`, only item `REMOVED` before public release; no current version submission; public lookup returns zero results |

Do not claim that no historical submission existed. The historical submission
completed, and its only item was removed before any public release.

## Agent preservation rules

1. Do not modify Swift source, tests, `project.yml`, generated Xcode files,
   runtime configuration, assets, screenshots, or evidence payloads for routine
   work. Do not run generators that can rewrite preserved project files.
2. Do not build a new release, increment a version, archive/export/upload a
   binary, restore TestFlight access, change App Store metadata, create a review
   submission, or publish this app.
3. Do not propagate future web API, schema, identity, or cut-plan changes into
   this retired client. The web app owns active Workshop evolution. Preserve
   dormant Apple backend/account compatibility until a separate phase is
   explicitly approved.
4. Do not remove Sign in with Apple capability, Apple keys, source, tests,
   assets, history, tags, branches, the Xcode project, or signing evidence.
   Allow app-specific provisioning profiles to expire naturally. Never revoke
   shared certificates or keys.
5. Do not archive or delete the GitHub repository. That remains a separate,
   explicit owner action.

## RETIRED - RESERVED

Never delete, transfer, recycle, or repurpose these identifiers for another
product:

- Team `3KB968X34U`
- App `6793709356`
- Version record `ab8c64ab-bf76-4c14-9b63-ab58630a59db`
- Bundle IDs `com.nintek.workshop`, `com.nintek.workshop.widgets`, and
  `com.nintek.workshop.share`

They preserve Apple ownership, signing and entitlement continuity, historical
App Store records, and compatibility with retained installations and account
data.

## Historical references

- **Cross-app standards:** <https://github.com/EnzoLopez2023/azure-infra/blob/main/STANDARDS.md>
- **Cross-repo product map:** <https://github.com/EnzoLopez2023/azure-infra/blob/main/PORTFOLIO.md>
- **App Store submission playbook:** <https://github.com/EnzoLopez2023/azure-infra/blob/main/APP_STORE_SUBMISSION.md>
- **Retirement authority:** `APP_STORE_STATUS.md`

The submission playbook and this machine's proven App Store tooling are
historical references, not instructions to submit Workshop. Nonsecret locators
remain Team ID `3KB968X34U`, Issuer ID
`cc6451f9-92e6-4a01-8e33-ce879517b98f`, and Key ID `334P495BAR`. The shared key
location remains
`~/.appstoreconnect/private_keys/AuthKey_334P495BAR.p8`; never commit or print
the key or a JWT, and never revoke it merely because Workshop is retired.

Agent sessions run in git worktrees, so relative paths into sibling repositories
do not resolve. Always use absolute GitHub URLs.

## Frozen implementation context

Workshop was a native SwiftUI woodworking planner for iOS 17, generated with
XcodeGen under scheme `Workshop`. It implemented 10 of the web app's 12 routes;
Notebook was deferred and `InsightsView` was native-only.

The [Workshop web app](https://github.com/EnzoLopez2023/workshop) shares the
Azure backend and Entra registration and remains canonical. The frozen native
app consumed [NintekKit](https://github.com/EnzoLopez2023/NintekKit), whose
`CutPlan.swift` mirrored the web implementation at retirement.

The preserved Microsoft identity behavior used `common` authority, retained a
bare `oid` for home tenant `52188f12-db6b-46c6-88ff-08c802f0ed3b`, and used
lowercase `<tid>_<oid>` for external principals. The Entra registration accepted
organizational and personal Microsoft accounts, issued v2 access tokens, exposed
`access_as_user`, and retained `msauth.com.nintek.workshop://auth`. These are
historical compatibility constraints, not invitations to change the retired
client.
