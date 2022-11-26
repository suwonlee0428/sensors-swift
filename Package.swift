// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "SwiftySensors",
    platforms: [.macOS(.v10_13), .iOS(.v9), .tvOS(.v9), .watchOS(.v4)],
    products: [
        .library(name: "SwiftySensors", targets: ["SwiftySensors"]),
    ],
    dependencies: [
        .package(url: "https://github.com/bejitono/Signals", .branch("master"))
    ],
    targets: [
        .target(name: "SwiftySensors", dependencies: ["Signals"])
    ]
)
