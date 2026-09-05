// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CarteClaire",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "CarteClaire", targets: ["CarteClaire"])
    ],
    targets: [
        .executableTarget(
            name: "CarteClaire",
            path: "Sources/CarteClaire"
        )
    ],
    swiftLanguageVersions: [.v5]
)
