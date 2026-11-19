// swift-tools-version:5.9
//
// RubyEmbed — this Ruby (mkxp-z 3.1.3 + QuestPlay patches) as a Swift package.
//
// Ruby-MKXPZ.xcframework is not committed: `make -f apple/Makefile xcframework`
// (from the repo root) writes it into this folder. It holds the merged static
// library + headers (ruby.h …) for macOS, iOS and the iOS Simulator; apps link
// it and #import <ruby.h> from Objective-C/C. It is a static library, so it is
// linked only, never embedded.

import PackageDescription

let package = Package(
    name: "RubyEmbed",
    platforms: [
        .macOS("15.4"),
        .iOS("18.4"),
    ],
    products: [
        .library(name: "RubyEmbed", targets: ["Ruby-MKXPZ"]),
    ],
    targets: [
        .binaryTarget(name: "Ruby-MKXPZ", path: "Ruby-MKXPZ.xcframework"),
    ]
)
