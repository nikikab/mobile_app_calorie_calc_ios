// swift-tools-version:5.9
import PackageDescription

// Platform-independent core of KaloCalc: the calculator, goals, diary rules and parsers.
// Foundation only, so it builds and tests on Linux (Docker) as well as in Xcode.
let package = Package(
    name: "KaloCalcCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "KaloCalcCore", targets: ["KaloCalcCore"])],
    targets: [
        .target(name: "KaloCalcCore"),
        .testTarget(name: "KaloCalcCoreTests", dependencies: ["KaloCalcCore"]),
    ]
)
