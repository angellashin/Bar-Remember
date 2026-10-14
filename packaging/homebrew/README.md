# Homebrew cask release preparation

`barremember.rb` mirrors the Cask published in
[`angellashin/homebrew-barremember`](https://github.com/angellashin/homebrew-barremember).
The public tap is the installation source of truth.

## Create a local release archive

```sh
Scripts/package-homebrew-cask.sh /tmp/barremember-release
```

The script builds an arm64 app in a temporary directory, writes a ZIP containing
`BarRemember.app`, and writes an adjacent SHA-256 file. It does not install or
modify any app in `/Applications` and it does not use quarantine workarounds.

## Current release constraints

The current public Cask supports macOS 14+ on Apple Silicon only. Its app is
ad-hoc signed and is neither Developer ID signed nor Apple-notarized. Gatekeeper
can therefore warn about or block the first launch. Do not work around that by
removing quarantine attributes or weakening Gatekeeper.

## Future signed release checklist

1. Build a release that is signed with a valid **Developer ID Application**
   certificate, hardened runtime enabled, and notarized by Apple.
2. Validate the notarized archive with `spctl --assess --type execute` and
   `stapler validate` before publishing it.
3. Publish the ZIP and its checksum to an approved public GitHub Release.
4. Set the Cask `version`, release URL, and SHA-256 to exactly match that release,
   then run Homebrew's Cask style/audit checks in the destination tap.

Never represent an ad-hoc arm64 build as Developer ID signed, notarized,
Gatekeeper-ready, or Intel-compatible.
