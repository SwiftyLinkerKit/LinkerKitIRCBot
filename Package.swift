// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LinkerKitIRCBot",
    products: [
        .library   (name: "LinkerKitIRCBot", targets: [ "LinkerKitIRCBot" ]),
        .executable(name: "lkircbot",        targets: [ "lkircbot" ])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/uraimo/SwiftyGPIO.git",
                 from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git",
                 from: "1.8.0"),
        .package(url: "https://github.com/NozeIO/swift-nio-irc.git",
                 from: "0.5.1"),
        .package(url: "https://github.com/NozeIO/swift-nio-irc-server.git",
                 from: "0.5.1"),
        .package(url: "https://github.com/NozeIO/swift-nio-irc-eliza.git",
                 from: "0.5.3"),
        .package(url: "https://github.com/NozeIO/swift-nio-irc-webclient.git",
                 from: "0.5.4"),
        .package(url: "https://github.com/SwiftyLinkerKit/SwiftyLinkerKit.git",
                 .branch("develop")) //from: "0.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "LinkerKitIRCBot",
            dependencies: [ "SwiftyLinkerKit", "IRC", "NIO" ]),
        .target(
            name: "lkircbot",
            dependencies: [ "SwiftyGPIO", "SwiftyLinkerKit",
                            "IRCServer", "IRCWebClient", "NIO", "IRCElizaBot",
                            "LinkerKitIRCBot" ]),
    ]
)
