// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Garcon",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Garcon", targets: ["Garcon"])
    ],
    targets: [
        .executableTarget(
            name: "Garcon",
            path: "Sources"
        )
    ]
)
