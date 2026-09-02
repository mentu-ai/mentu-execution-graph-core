// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MentuExecutionGraphCoreConsumerFixture",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(
            name: "mentu-execution-graph-core",
            path: "../.."
        ),
    ],
    targets: [
        .executableTarget(
            name: "ConsumerFixture",
            dependencies: [
                .product(
                    name: "MentuExecutionGraphCore",
                    package: "mentu-execution-graph-core"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
