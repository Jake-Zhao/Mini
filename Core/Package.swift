// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "JakeCore", platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "JakeCore", targets: ["JakeCore"])],
    targets: [.target(name: "JakeCore"), .testTarget(name: "JakeCoreTests", dependencies: ["JakeCore"])],
    swiftLanguageModes: [.v5]
)
