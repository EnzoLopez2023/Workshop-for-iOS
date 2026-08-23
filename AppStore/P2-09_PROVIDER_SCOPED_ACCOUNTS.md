# P2-09 provider-scoped account audit

Audit date: 2026-08-23

Audited release: Workshop 2.2.1 (12), source
`a6d80030d9ee3c0f1c96dcc02883710de6215d54`

## Decision

Sign in with Apple and Microsoft/Entra are deliberately independent identity
paths:

- each provider creates a separate Workshop account and workspace;
- using the same email address with both providers does not merge them;
- there is no automatic link, merge, or transfer between providers; and
- account deletion applies only to the currently authenticated provider-scoped
  Workshop identity. It does not delete the underlying Apple or Microsoft
  account or a Workshop account created with the other provider.

This is the product contract, not a temporary implementation limitation.

## Implementation evidence

The storage and deletion behavior is correctly provider-scoped:

- `Workshop/Auth/MSALAuth.swift` derives Microsoft identities from Entra
  `tid`/`oid`. The home tenant retains the legacy bare `oid`; every other tenant,
  including personal Microsoft accounts, uses lowercase `<tid>_<oid>`.
- `Workshop/Auth/AppleAuth.swift` receives a backend-issued user key in the
  `apple_<sha256(sub)>` namespace and stores only that Apple-backed session.
- `Workshop/App/AppModel.swift` configures one authenticated `WorkshopAPI` at a
  time. `deleteAccount()` calls `DELETE /api/account` through that current
  provider's token, clears local surfaces only after server success, and then
  signs out.
- No account-link, merge, transfer, email-match, or cross-provider deletion path
  exists in the audited app source.
- `WorkshopTests/EntraIdentityTests.swift` covers the home-tenant compatibility
  rule, external-tenant namespacing, personal Microsoft-account namespacing,
  normalization, and malformed claims.
- No native automated test currently asserts the Apple `apple_<sha256(sub)>`
  namespace, cross-provider non-collision, provider labeling, or provider-scoped
  deletion copy. Those are next-build evidence gaps, not proof of linking.
- The public privacy and support pages explicitly describe separate accounts,
  separate data/deletion scopes, and the lack of automatic linking.

The public support page's provider boundary is correct, but its deletion
navigation is stale: it says `Settings -> Account & Data` while build 12 uses
`More -> Account`. Correct that external page before review.

## Build 12 release verdict

**Blocked for App Review/public release; safe to retain in internal TestFlight.**

The attached binary implements the correct data boundary but does not explain it
at the two moments where a user must understand it:

1. The sign-in screen offers Apple and Microsoft without saying that they open
   separate workspaces, even for the same email address.
2. More -> Account shows only `Signed in as <name>`, not the active provider.
   Its deletion footer and confirmation say that "your Workshop" data is deleted
   without limiting that statement to the current provider-scoped account.

The in-app Privacy Policy and Workshop Support links lead to accurate public
explanations, but a separate document is not a substitute for contextual copy at
provider selection and before a destructive action.

No source, build, TestFlight, screenshot, metadata, price, territory, or review
submission mutation was made by this audit.

## Exact next-build requirements

The next binary must add all of the following before it replaces build 12:

1. **Sign-in disclosure**

   Place this readable, Dynamic Type-compatible text with the Apple/Microsoft
   choices:

   > Apple and Microsoft create separate Workshop accounts. Use the same
   > provider each time to return to the same projects. Accounts are not linked
   > automatically.

2. **Active-provider identity**

   More -> Account must identify both the display name and provider, for example
   `Provider: Apple` or `Provider: Microsoft`. Do not infer the provider from a
   name or email address.

3. **Provider-scoped deletion footer**

   Use provider-aware copy with this meaning:

   > Delete Account permanently removes only this Apple/Microsoft Workshop
   > account and its projects, photos, lists, and uploads. It does not delete
   > your Apple/Microsoft account or a Workshop account created with the other
   > provider.

4. **Provider-scoped confirmation**

   The destructive confirmation must repeat that the operation affects only
   the current provider-scoped Workshop account and cannot be undone.

5. **Automated coverage**

   Add source/unit coverage for the Apple/Microsoft provider label,
   cross-provider non-collision, and provider-specific deletion copy; retain
   backend/integration evidence that deletion affects only the authenticated
   provider key. Add a UI assertion that the sign-in disclosure is visible at
   supported Dynamic Type sizes. Preserve the existing Entra identity tests.

6. **Release evidence**

   Increment the build number, rerun app/extensions/tests/Release/archive,
   inspect the signed export, replace the attached build only after it is
   `VALID`, and re-record the account/deletion portion of the physical-device
   Guideline 2.1 evidence. Do not relabel build-12 evidence as proof of the new
   copy. Correct the public support deletion path to `More -> Account` at the
   same release gate.

## Acceptance checklist

- [ ] Apple sign-in creates/returns to only the Apple-backed workspace.
- [ ] Microsoft sign-in creates/returns to only the selected Entra-backed
      workspace.
- [ ] Switching providers does not merge projects, uploads, or exports.
- [ ] Account settings visibly identify the current provider.
- [ ] Deleting Apple-backed data leaves the Microsoft-backed workspace intact.
- [ ] Deleting Microsoft-backed data leaves the Apple-backed workspace intact.
- [ ] Deletion never claims to delete the underlying Apple or Microsoft account.
- [ ] Reviewer notes and physical-device recording state the same provider
      boundary as the binary and public policy.
