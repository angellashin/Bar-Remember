# Homebrew cask release preparation

`barremember.rb` is an intentionally unpublished template. Its `example.invalid`
URL and checksum placeholder prevent it from being a working install source before
an approved public release exists.

## Create a local release archive

```sh
Scripts/package-homebrew-cask.sh /tmp/barremember-release
```

The script builds an arm64 app in a temporary directory, writes a ZIP containing
`BarRemember.app`, and writes an adjacent SHA-256 file. It does not install or
modify any app in `/Applications` and it does not use quarantine workarounds.

## Before public publication

1. Build a release that is signed with a valid **Developer ID Application**
   certificate, hardened runtime enabled, and notarized by Apple.
2. Validate the notarized archive with `spctl --assess --type execute` and
   `stapler validate` before publishing it.
3. Publish the ZIP and its checksum to an approved public GitHub Release.
4. Set the cask `version`, release URL, and SHA-256 to exactly match that release,
   then run Homebrew's cask style/audit checks in the destination tap.

The current local build is ad-hoc signed and arm64-only. It must not be represented
as Developer ID signed, notarized, Gatekeeper-ready, or Intel-compatible.
