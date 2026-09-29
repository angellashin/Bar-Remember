# Contributing to BarRemember

Thanks for helping improve BarRemember.

## Before you start

- Search existing issues before opening a new one.
- Do not include private reminder titles, account details, or personal screenshots.
- For a visual change, attach a before/after screenshot and explain the interaction you tested.

## Development setup

1. Install macOS 14 or later and Xcode 16.4 or later.
2. Clone the repository and run `Scripts/build-app.sh`.
3. Open `dist/BarRemember.app` and grant Reminders access when prompted.
4. Run `swift test` with the Xcode toolchain before submitting a pull request.

## Pull requests

- Keep each pull request focused on one problem.
- Add regression coverage for policy or data changes.
- Update the English README when user-facing behavior changes.
- Keep English and Korean entries in sync in `Resources/*/Localizable.strings`.
- Describe any macOS permission, EventKit, or accessibility impact in the pull request body.

## Commit messages

Use a short imperative subject, for example `Improve Glass theme contrast`. Include the reason for a behavior change in the body when it is not obvious from the diff.

## Review expectations

Maintainers will review correctness, privacy, accessibility, localization, and consistency with the existing SwiftUI/AppKit design. A maintainer may ask for a narrower scope or additional screenshots before merging.
