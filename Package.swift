// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pickle",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Pickle",
            path: "Sources/Pickle",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
