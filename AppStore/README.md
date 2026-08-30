# App Store assets

This directory classifies release inputs and tracked review-preparation
evidence. Generated captures and screenshot files stay local and ignored.

- App UI source is the exact release commit under `Workshop/`, `Shared/`,
  `WorkshopWidgets/`, and `WorkshopShareExtension/`.
- App icon source is the three rendition files in
  `Workshop/Assets.xcassets/AppIcon.appiconset/`.
- `WorkshopVisualUITests.testAppStoreScreenshotStory` captures the same
  five-screen story on iPhone and iPad: dashboard, project detail, shopping,
  conversion tables, and insights.
- `Scripts/flatten-simulator-screenshot.swift` applies the simulator display
  mask and writes opaque JPEG files. The expected local sets are five
  `1320x2868` files under `AppStore/Screenshots/iPhone-6.9/` and five
  `2064x2752` files under `AppStore/Screenshots/iPad-13/`.
- `AppStore/RELEASE_VISUAL_MANIFEST.json` is authoritative for the icon,
  app/widget/share visual variants, exact screenshot order, dimensions, byte
  sizes, SHA-256 hashes, App Store Connect asset IDs, capture commands, release
  source, Concourse-residue result, and nintek/social handoff.
- Regenerate the local masters with
  `Scripts/capture-app-store-screenshots.sh "$IPHONE_69_SIMULATOR_UDID" "$IPAD_13_SIMULATOR_UDID"`.
  The script stages and validates both sets before replacing the prior files.
- App Store screenshots must show the actual release UI. Simulator captures are
  listing candidates; complete Guideline 2.1 recording evidence on physical
  iPhone and iPad hardware as required by the
  [shared submission playbook](https://github.com/EnzoLopez2023/azure-infra/blob/main/APP_STORE_SUBMISSION.md).
- `AppStore/Captures/` and `AppStore/Screenshots/` are intentionally ignored.
  The retired title-art compositor and its seven outputs remain recoverable from
  git history at commit `5e1d064`; they are not current product or submission
  assets and must not be uploaded.

Current upload and draft metadata state is recorded in `APP_STORE_STATUS.md`.
Source cleanup itself never creates an App Review submission.
