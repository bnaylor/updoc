// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "updoc",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "updoc", targets: ["updoc"]),
    ],
    dependencies: [
        // Dependencies will go here
    ],
    targets: [
        .executableTarget(
            name: "updoc",
            dependencies: [],
            path: "src/updoc"
        ),
        .testTarget(
            name: "updocTests",
            dependencies: ["updoc"],
            path: "tests/updocTests"
        ),
    ]
)
