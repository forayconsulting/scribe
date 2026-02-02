# Scribe

A simple macOS app for recording meetings and getting speaker-diarized transcripts.

## Features

- **Dual audio capture**: Records both system audio (via ScreenCaptureKit) and microphone simultaneously
- **Source-aware diarization**: Transcribes mic and system audio separately, labeling your speech with your configured name while remote speakers get OpenAI's diarization
- **OpenAI transcription**: Uses `gpt-4o-transcribe` for accurate speech-to-text
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
3. Set your name in Settings under "Speaker Identity" (this labels your microphone speech in transcripts)
4. Grant Screen Recording and Microphone permissions when prompted
5. Click the record button to start capturing
6. Click stop when done
7. Wait for transcription to complete (mic and system audio are transcribed separately)
8. Your transcript opens automatically as a Markdown file

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
│   ├── AudioChunker.swift       # Splits audio for API limits
│   ├── AudioConverter.swift     # Converts mic CAF to M4A for API
│   ├── AudioMerger.swift        # Legacy audio merging (unused)
│   ├── MarkdownFormatter.swift  # Transcript formatting
│   └── TranscriptionMerger.swift # Merges mic + system transcripts
└── Models/
    ├── RecordingState.swift
    ├── TranscriptionResult.swift
    └── TranscriptionSegment.swift
```

## How It Works

1. **Recording**: Captures system audio via ScreenCaptureKit (M4A) and microphone via AVAudioEngine (CAF) simultaneously as separate files
2. **Conversion**: Converts microphone CAF to M4A for API compatibility
3. **Transcription**: Sends each audio source to OpenAI separately—mic audio gets your configured speaker name, system audio uses OpenAI's diarization for remote speakers
4. **Merging**: Combines both transcription results, sorting segments by timestamp
5. **Formatting**: Converts merged results to timestamped Markdown with speaker labels

## License

Private project.
