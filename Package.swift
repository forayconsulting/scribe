// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Scribe",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Scribe", targets: ["Scribe"])
    ],
    targets: [
        .executableTarget(
            name: "Scribe",
            path: "Scribe",
            exclude: ["Info.plist", "Scribe.entitlements"],
            sources: [
                "ScribeApp.swift",
                "Models/RecordingState.swift",
                "Models/TranscriptionSegment.swift",
                "Models/TranscriptionResult.swift",
                "Services/AudioCaptureService.swift",
                "Services/AudioFileWriter.swift",
                "Services/KeychainService.swift",
                "Services/MicrophoneCaptureService.swift",
                "Services/TranscriptionService.swift",
                "Utilities/AudioChunker.swift",
                "Utilities/AudioConverter.swift",
                "Utilities/AudioMerger.swift",
                "Utilities/MarkdownFormatter.swift",
                "Utilities/TranscriptionMerger.swift",
                "ViewModels/RecordingViewModel.swift",
                "Views/ContentView.swift",
                "Views/MicTestView.swift",
                "Views/RecordingView.swift",
                "Views/ProcessingView.swift",
                "Views/SettingsView.swift",
                "Views/Components/RecordButton.swift",
                "Views/Components/PermissionBanner.swift"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
