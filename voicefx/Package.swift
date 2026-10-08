// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "voicefx",
    platforms: [.macOS(.v15)],
    targets: [
        // Pure DSP: no CoreAudio, testable offline and portable.
        .target(name: "DSP"),
        // macOS host: CoreAudio I/O, UDP control, WAV render.
        .executableTarget(name: "voicefx", dependencies: ["DSP"]),
        .testTarget(name: "DSPTests", dependencies: ["DSP"]),
    ]
)
