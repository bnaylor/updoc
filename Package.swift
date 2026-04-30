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
        .package(url: "https://github.com/google/GTMAppAuth", from: "4.1.1"),
        .package(url: "https://github.com/openid/AppAuth-iOS.git", from: "1.7.5")
    ],
    targets: [
        .executableTarget(
            name: "updoc",
            dependencies: [
                .product(name: "GTMAppAuth", package: "GTMAppAuth"),
                .product(name: "AppAuth", package: "AppAuth-iOS")
            ],
            path: "src/updoc",
            exclude: [
                "Info.plist",
                "entitlements.plist"
            ],
            resources: [
                .copy("Resources/editor")
            ]
        ),
        .testTarget(
            name: "updocTests",
            dependencies: ["updoc"],
            path: "tests/updocTests"
        ),
    ]
)
