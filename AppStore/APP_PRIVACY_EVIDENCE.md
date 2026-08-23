# Workshop App Privacy evidence

Release candidate: Workshop 2.2.1 (12)

This is the source evidence for App Store Connect's App Privacy UI. The public
API cannot read or publish App Privacy answers, so the signed-in UI must still
be opened, compared with this record, published, and read back before review.

## Collected data

| Data type | Linked to the user | Purpose | Tracking |
|---|---:|---|---:|
| Name | Yes | App Functionality | No |
| Email Address | Yes | App Functionality | No |
| User ID | Yes | App Functionality | No |
| Photos or Videos | Yes | App Functionality | No |
| Other User Content | Yes | App Functionality | No |

Evidence:

- `Workshop/PrivacyInfo.xcprivacy` declares the five types above.
- Microsoft Entra and Sign in with Apple provide independent provider-scoped
  account identities. Matching email addresses do not link or merge their
  Workshop data. Apple may provide a private relay address.
- Projects, Shaper projects, parts, cut lists, materials, shopping lists,
  finish records, build logs, notes, links, photos, PDFs, and imported project
  drafts are retained in the signed-in Workshop account.
- Optional project URL analysis sends the user-selected public page through the
  Workshop service to Anthropic only after the user requests analysis.
- Deletion applies only to the current provider-scoped Workshop account. It
  leaves the underlying Apple/Microsoft account and any Workshop account created
  through the other provider intact.
- There is no advertising, analytics SDK, ATT prompt, cross-app tracking,
  StoreKit purchase, subscription, or in-app purchase.

## Required-reason APIs and extensions

| Bundle | Collected data | UserDefaults reasons |
|---|---|---|
| `com.nintek.workshop` | Five linked App Functionality types above | `CA92.1`, `1C8F.1` |
| `com.nintek.workshop.widgets` | None | `1C8F.1` |
| `com.nintek.workshop.share` | None | `1C8F.1` |

The widget and share extension do not authenticate or call the network. They
read or write only the compact App Group snapshot/queue.

## Public disclosures

- Privacy: <https://www.nintek.com/workshop/privacy>
- Support: <https://www.nintek.com/workshop/support>
- Terms: <https://www.nintek.com/terms>

The policy covers Azure account storage, Apple/Microsoft identity boundaries,
uploads, optional URL analysis, App Group snapshots, account deletion, and
backup retention. All three URLs must return the intended public page from a
signed-out browser immediately before submission.

The current public pages intentionally describe the native release as withdrawn
while rework and private TestFlight preparation continue. Before any App Review
submission, update that release-state copy to match the exact candidate and
confirm neither page tells the reviewer that the submitted build is withdrawn.

## App Store Connect gate

- Keep the five data types linked to the user, used for App Functionality, and
  not used for tracking.
- Confirm the answers are published, not merely saved as a draft.
- Re-open the privacy page and compare the published summary with this file and
  the signed archive.
