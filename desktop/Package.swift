// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "AD2KitArchitect",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AD2KitArchitect", targets: ["AD2KitArchitect"]),
    ],
    targets: [
        .executableTarget(name: "AD2KitArchitect"),
    ]
)
