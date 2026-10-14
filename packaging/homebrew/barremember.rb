# LOCAL PUBLISHING TEMPLATE ONLY.
# Replace the example.invalid URL and checksum with the values from the approved
# public GitHub Release before placing this cask in a public tap.
cask "barremember" do
  version "1.4.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE_ARCHIVE"

  url "https://example.invalid/BarRemember-#{version}-macos-arm64.zip"
  name "BarRemember"
  desc "Native macOS menu bar companion for Apple Reminders"
  homepage "https://github.com/angellashin/Bar-Remember"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "BarRemember.app"
end
