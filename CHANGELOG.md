# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

Entries below start from the `3.0.0` release; see the git tags for the history
of earlier releases.

## [3.0.0] - 2026-09-03

### Breaking

- `AuthgearDelegate.authgearSessionStateDidChange(_:reason:)` now takes an
  additional `error: Error?` parameter:
  `authgearSessionStateDidChange(_:reason:error:)`. This has a default
  no-op implementation, so an app implementing the old signature will
  **compile without any error or warning but silently stop receiving the
  callback**. Update any `AuthgearDelegate` conformer to the new signature.

### Added

- `authenticators` and `recoveryCodeEnabled` fields on user info.

### Changed

- A token refresh that fails with `invalid_dpop_proof` now clears the
  session, matching existing behavior for `invalid_grant`.
- Logs now record whether a session-clear error was `invalid_grant` or
  `invalid_dpop_proof`.

### Deprecated

- `SettingsPage.identity` is deprecated in favor of `Settings` and
  `changeEmail`/`changePhone`.
