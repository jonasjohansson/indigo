// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "InNDIGo",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "CSyphon",
            path: "Sources/CSyphon",
            exclude: [],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("."),
                .define("GL_SILENCE_DEPRECATION"),
                .unsafeFlags(["-fmodules", "-fcxx-modules", "-Wno-deprecated-declarations", "-include", "SyphonPrefix.h"])
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("IOSurface"),
                .linkedFramework("OpenGL"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        .target(
            name: "CNDI",
            path: "Sources/CNDI",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-I/Library/NDI SDK for Apple/include"])
            ],
            linkerSettings: [
                .unsafeFlags(["-L/Library/NDI SDK for Apple/lib/macOS", "-lndi", "-Xlinker", "-rpath", "-Xlinker", "/Library/NDI SDK for Apple/lib/macOS"])
            ]
        ),
        .executableTarget(
            name: "InNDIGo",
            dependencies: ["CSyphon", "CNDI"],
            path: "Sources/InNDIGo",
            exclude: ["Info.plist", "InNDIGo.entitlements"]
        )
    ]
)
