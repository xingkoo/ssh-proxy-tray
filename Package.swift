// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ssh-proxy-tray",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SSHProxyCore", targets: ["SSHProxyCore"]),
        .executable(name: "SSHProxyTray", targets: ["SSHProxyTray"]),
        .executable(name: "SSHAskPass", targets: ["SSHAskPass"]),
        .executable(name: "ssh-proxy-trayctl", targets: ["SSHProxyTrayCLI"])
    ],
    targets: [
        .target(name: "SSHProxyCore"),
        .executableTarget(
            name: "SSHProxyTray",
            dependencies: ["SSHProxyCore"]
        ),
        .executableTarget(name: "SSHAskPass"),
        .executableTarget(
            name: "SSHProxyTrayCLI",
            dependencies: ["SSHProxyCore"]
        ),
        .testTarget(
            name: "SSHProxyCoreTests",
            dependencies: ["SSHProxyCore"]
        )
    ]
)
