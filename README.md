# Scribe

A simple macOS app for recording meetings and getting speaker-diarized transcripts.

## Features

- **Dual audio capture**: Records both system audio (via ScreenCaptureKit) and microphone simultaneously
- **Energy-based speaker attribution**: Merges audio tracks for high-quality transcription, then attributes each segment to mic or system based on audio energy analysis
- **OpenAI transcription**: Uses `whisper-1` with `verbose_json` for accurate speech-to-text with segment timestamps
- **Turn-based formatting**: Collapses consecutive segments from the same speaker into coherent turns
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
7. Wait for transcription to complete
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
│   ├── AudioFileWriter.swift          # M4A file writing
│   ├── TranscriptionService.swift     # OpenAI API integration
│   └── KeychainService.swift          # Secure credential storage
├── Utilities/
│   ├── AudioChunker.swift         # Splits audio for API limits
│   ├── AudioConverter.swift       # Converts mic CAF to M4A for API
│   ├── AudioMerger.swift          # Merges mic + system into single file
│   ├── AudioSourceAttributor.swift # Attributes segments by energy analysis
│   ├── AudioRegionExtractor.swift  # Extracts time regions from audio
│   ├── SpeechRegionDetector.swift  # Detects speech regions via energy
│   ├── MarkdownFormatter.swift     # Transcript formatting with turn collapsing
│   └── TranscriptionMerger.swift   # Legacy merger (unused)
└── Models/
    ├── RecordingState.swift
    ├── TranscriptionResult.swift
    └── TranscriptionSegment.swift
```

## How It Works

1. **Recording**: Captures system audio via ScreenCaptureKit (M4A) and microphone via AVAudioEngine (CAF) simultaneously as separate files
2. **Merging**: Combines mic and system audio into a single file for transcription
3. **Transcription**: Sends merged audio to OpenAI Whisper API once, preserving full context for high-quality results
4. **Attribution**: Analyzes energy levels in the original separate files to determine which source (mic or system) each transcribed segment came from
5. **Formatting**: Collapses consecutive segments from the same speaker into turns, then outputs timestamped Markdown with speaker labels

## Why This Approach?

Earlier iterations tried:
- Transcribing mic and system separately, then merging by timestamp → timestamps didn't align (different file timelines)
- Detecting speech regions and transcribing chunks → quality degraded without full context
- Various offset calculations → Whisper's timestamp handling varies by content

The current approach (merge → transcribe once → attribute by energy) solves all these issues:
- **Full context**: Whisper sees complete audio, producing coherent transcription
- **Accurate timing**: Single timeline, no alignment issues
- **Reliable attribution**: Energy-based detection doesn't depend on Whisper's internal decisions

## License

Private project.
