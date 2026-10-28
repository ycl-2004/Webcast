// swift-tools-version:5.7
import PackageDescription

// Google's 4.8.6 dynamic archive already includes GTMSessionFetcher classes.
// Keep this binary-only manifest until the upstream wrapper avoids linking them twice.
// Version and checksum match googlecast/google-cast-ios-sdk's 4.8.6 Package.swift.
let package = Package(
    name: "GoogleCast",
    platforms: [.iOS(.v16)],
    products: [.library(name: "GoogleCastDynamic", targets: ["GoogleCast"])],
    targets: [
        .binaryTarget(
            name: "GoogleCast",
            url: "https://dl.google.com/dl/chromecast/sdk/ios/GoogleCastSDK-ios-4.8.6_dynamic.zip",
            checksum: "55f6c21291a1315c68063f07e7d76225564bff70f2fd38caad135c71d66eb310"
        )
    ]
)
