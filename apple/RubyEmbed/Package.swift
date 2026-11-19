// swift-tools-version:5.9
//
// RubyEmbed — this Ruby (mkxp-z 3.1.3 + QuestPlay patches) as a Swift package.
//
// Generated content is not committed; `make -f apple/Makefile` (from the repo
// root) writes it into this folder:
//   - Ruby-MKXPZ.xcframework: the merged static library + headers (ruby.h …)
//     for macOS, iOS and the iOS Simulator. Apps link it and #import <ruby.h>
//     from Objective-C/C. Static, so linked only, never embedded.
//   - Sources/RubyEmbed/ruby/: the Ruby files the interpreter loads at runtime
//     (stdlib + per-platform rbconfig.rb).
//
// A binary target can't carry resources or linker settings, so the RubyEmbed
// target does: it ships ruby/ and exposes RubyEmbedLoadPaths(), the folders to
// pass to ruby_options() as -I.

import PackageDescription

let package = Package(
    name: "RubyEmbed",
    platforms: [
        .macOS("15.4"),
        .iOS("18.4"),
    ],
    products: [
        .library(name: "RubyEmbed", targets: ["RubyEmbed", "Ruby-MKXPZ"]),
    ],
    targets: [
        .binaryTarget(name: "Ruby-MKXPZ", path: "Ruby-MKXPZ.xcframework"),
        .target(
            name: "RubyEmbed",
            dependencies: ["Ruby-MKXPZ"],
            resources: [.copy("ruby")],
            linkerSettings: [
                .linkedLibrary("z"),                // Ruby's zlib extension
                .linkedFramework("CoreFoundation"), // file.c path normalization
            ]
        ),
    ]
)
