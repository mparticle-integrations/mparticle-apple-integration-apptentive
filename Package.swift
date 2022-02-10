// swift-tools-version:5.5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mParticle-Apptentive",
    platforms: [ .iOS(.v13) ],
    products: [
        .library(
            name: "mParticle-Apptentive",
            targets: ["mParticle-Apptentive"]),
    ],
    dependencies: [
      .package(name: "mParticle-Apple-SDK",
               url: "https://github.com/mParticle/mparticle-apple-sdk",
               .upToNextMajor(from: "8.0.0")),
      .package(name: "Apptentive",
               url: "https://github.com/gymshark/apptentive-ios",
               .upToNextMajor(from: "5.0.0")),
    ],
    targets: [
        .target(
            name: "mParticle-Apptentive",
            dependencies: [
              .byName(name: "mParticle-Apple-SDK"),
              .byName(name: "Apptentive")
            ],
            path: "./mParticle-Apptentive",
            exclude: ["Info.plist"]
        )
    ]
)
