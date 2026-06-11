// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SkillTestUI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SkillTestUI", targets: ["SkillTestUI"]),
    ],
    targets: [
        .target(name: "SkillTestUI"),
    ]
)
