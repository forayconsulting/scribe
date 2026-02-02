# Scribe

A simple macOS app for recording meetings and getting speaker-diarized transcripts.

## Features

- **Dual audio capture**: Records both system audio (via ScreenCaptureKit) and microphone simultaneously
- **OpenAI transcription**: Uses `gpt-4o-transcribe` for accurate speech-to-text with speaker diarization
- **Markdown output**: Generates timestamped, speaker-labeled transcripts
- **Secure API key storage**: OpenAI API key stored in macOS Keychain

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon or Intel Mac
- OpenAI API key
- Screen Recording permission (for system audio capture)
- Microphone permission

## Usage

1. Launch Scribe
2. Enter your OpenAI API key in Settings (gear icon)
3. Grant Screen Recording and Microphone permissions when prompted
4. Click the record button to start capturing
5. Click stop when done
6. Wait for transcription to complete
7. Your transcript opens automatically as a Markdown file

## Building

```bash
cd Scribe
swift build
```

To run:
```bash
open Scribe.app
```

Or run the executable directly:
```bash
.build/arm64-apple-macosx/debug/Scribe
```

## Architecture

```
Scribe/
├── ScribeApp.swift              # App entry point
├── Views/
│   ├── ContentView.swift        # Main window
│   ├── RecordingView.swift      # Recording UI
│   ├── ProcessingView.swift     # Transcription progress
│   ├── SettingsView.swift       # API key configuration
│   ├── MicTestView.swift        # Microphone testing utility
│   └── Components/
│       ├── RecordButton.swift   # Animated record button
│       └── PermissionBanner.swift
├── ViewModels/
│   └── RecordingViewModel.swift # Recording state management
├── Services/
│   ├── AudioCaptureService.swift      # System audio (ScreenCaptureKit)
│   ├── MicrophoneCaptureService.swift # Microphone (AVCaptureSession)
│   ├── AudioFileWriter.swift          # CAF file writing
│   ├── TranscriptionService.swift     # OpenAI API integration
│   └── KeychainService.swift          # Secure credential storage
├── Utilities/
│   ├── AudioMerger.swift        # Combines mic + system audio
│   ├── AudioChunker.swift       # Splits audio for API limits
│   └── MarkdownFormatter.swift  # Transcript formatting
└── Models/
    ├── RecordingState.swift
    ├── TranscriptionResult.swift
    └── TranscriptionSegment.swift
```

## How It Works

1. **Recording**: Captures system audio via ScreenCaptureKit and microphone via AVCaptureSession simultaneously, writing each to separate CAF files
2. **Merging**: Combines both audio streams into a single file using AVFoundation
3. **Chunking**: Splits long recordings into chunks under OpenAI's file size limit
4. **Transcription**: Sends audio to OpenAI's transcription API with diarization enabled
5. **Formatting**: Converts API response to timestamped Markdown with speaker labels

## License

Private project.
