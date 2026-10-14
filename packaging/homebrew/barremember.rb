cask "barremember" do
  version "1.4.0"
  sha256 "00949e3caef5f08fb5f2268fd71a5d4b38dc8ba1da9ed08d7186ab1cef0fb783"

  url "https://github.com/angellashin/Bar-Remember/releases/download/v#{version}/BarRemember-#{version}-macos-arm64.zip"
  name "BarRemember"
  desc "Menu bar companion for Apple Reminders"
  homepage "https://github.com/angellashin/Bar-Remember"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "BarRemember.app"
end
