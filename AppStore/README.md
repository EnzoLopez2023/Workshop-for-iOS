# App Store assets

This directory classifies release inputs; it does not contain a current
screenshot set.

- App UI source is the exact release commit under `Workshop/`, `Shared/`,
  `WorkshopWidgets/`, and `WorkshopShareExtension/`.
- App icon source is the three rendition files in
  `Workshop/Assets.xcassets/AppIcon.appiconset/`.
- App Store screenshots must show the actual release build. Capture layout
  candidates in Simulator, then complete final evidence on physical iPhone and
  iPad hardware as required by the
  [shared submission playbook](https://github.com/EnzoLopez2023/azure-infra/blob/main/APP_STORE_SUBMISSION.md).
- `AppStore/Captures/` and `AppStore/Screenshots/` are intentionally ignored.
  The retired title-art compositor and its seven outputs remain recoverable from
  git history at commit `5e1d064`; they are not current product or submission
  assets.

No upload or review submission is performed by source cleanup work.
