// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NewsDaily",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "NewsDaily",
            targets: ["NewsDaily"]
        )
    ],
    targets: [
        .executableTarget(
            name: "NewsDaily",
            path: "Sources/NewsDaily",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NewsDailyTests",
            dependencies: ["NewsDaily"],
            path: "Tests/NewsDailyTests"
        )
    ]
)
