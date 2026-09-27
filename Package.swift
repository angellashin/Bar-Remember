// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "BarRemember",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "BarRemember", targets: ["BarRemember"])
  ],
  targets: [
    .executableTarget(
      name: "BarRemember",
      path: "Sources/BarRemember"
    ),
    .testTarget(
      name: "BarRememberTests",
      dependencies: ["BarRemember"],
      path: "Tests/BarRememberTests"
    ),
  ]
)
