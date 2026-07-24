// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MeetingLink",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MeetingLink", targets: ["MeetingLink"])
    ],
    targets: [
        .target(name: "MeetingLink"),
        .testTarget(name: "MeetingLinkTests", dependencies: ["MeetingLink"])
    ]
)
