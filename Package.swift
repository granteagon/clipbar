// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ClipBar", platforms: [.macOS(.v13)], products: [.executable(name: "ClipBar", targets: ["ClipBar"])], targets: [.target(name: "ClipBarCore"), .executableTarget(name: "ClipBar", dependencies: ["ClipBarCore"]), .testTarget(name: "ClipBarCoreTests", dependencies: ["ClipBarCore", "ClipBar"])])
