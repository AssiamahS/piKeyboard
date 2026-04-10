// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "pid-mac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "pikeyboardd", targets: ["pid-mac"]),
    ],
    targets: [
        .executableTarget(
            name: "pid-mac",
            path: "Sources"
        ),
    ]
)
