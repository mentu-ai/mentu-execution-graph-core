// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mentu-execution-graph-core",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "MentuExecutionGraphCore",
            targets: ["MentuExecutionGraphCore"]
        ),
    ],
    targets: [
        .target(name: "MentuExecutionGraphCore"),
        .testTarget(
            name: "MentuExecutionGraphCoreTests",
            dependencies: ["MentuExecutionGraphCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
