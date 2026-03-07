// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jobcelis",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "Jobcelis", targets: ["Jobcelis"])
    ],
    targets: [
        .target(name: "Jobcelis")
    ]
)
