# Workshop reviewer account checklist

Use the non-secret reference `workshop-asc-reviewer`. Never write its username,
password, recovery codes, tokens, or private video access secret to git.

- [ ] Create or refresh a dedicated Microsoft reviewer principal, not a
      personal or customer account.
- [ ] Seed synthetic projects, parts, materials, shopping items, photos, a safe
      PDF, finish records, and build-log entries that exercise the core flow.
- [ ] Verify the exact credentials from a clean physical iPhone and iPad on an
      external network.
- [ ] Confirm there is no first-login password reset, tenant-consent prompt,
      CAPTCHA, MFA, OTP, owner approval, device-compliance requirement, or
      conditional-access block.
- [ ] Put credentials only in App Store Connect's protected App Review
      Information username/password fields.
- [ ] Verify sign-in, refresh, foreground/background, force-quit/relaunch,
      offline error handling, and sign-out.
- [ ] Confirm the UI identifies Microsoft as the active provider and states that
      Apple and Microsoft open separate, unlinked Workshop workspaces.
- [ ] Record permanent account deletion, then recreate/reseed the principal and
      immediately reverify the credentials Apple will receive.
- [ ] Exercise Sign in with Apple separately without sharing a personal Apple
      ID in notes, source, screenshots, or recordings.
- [ ] Verify each provider's deletion removes only its own Workshop identity and
      leaves the other provider's workspace intact.
- [ ] Keep the reviewer account and production services available throughout
      review.
- [ ] Before App Review submission, update the public privacy/support
      release-state copy so it no longer describes the submitted native build as
      withdrawn; verify both pages signed out.
- [ ] Recheck access, service health, and conditional-access behavior within
      seven days before submission or resubmission.
