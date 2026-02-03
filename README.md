# Scribe

A simple macOS app for recording meetings and getting speaker-diarized transcripts.

## Features

- **Dual audio capture**: Records both system audio (via ScreenCaptureKit) and microphone simultaneously
- **Multi-session support**: Start a new recording in a separate window while a previous transcription is still processing (Cmd+Shift+N)
- **Multi-speaker diarization**: System audio speakers are automatically labeled (Speaker A, Speaker B, etc.) via OpenAI's diarization; mic input is attributed to your configured name via energy analysis
- **Post-transcription speaker renaming**: After transcription, review and rename speakers before saving—see sample text from each speaker to identify who's who
- **OpenAI transcription**: Uses `gpt-4o-transcribe-diarize` with `diarized_json` for accurate speech-to-text with multi-speaker diarization
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
8. Review the speaker renaming screen—edit names as needed or click "Skip" to keep defaults
9. Save your transcript as a Markdown file

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
│   ├── SpeakerRenamingView.swift # Post-transcription speaker naming
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
    ├── RecordingSession.swift       # Session identity for multi-window support
    ├── RecordingState.swift
    ├── SpeakerRenameMapping.swift
    ├── TranscriptionResult.swift
    └── TranscriptionSegment.swift
```

## How It Works

1. **Recording**: Captures system audio via ScreenCaptureKit (M4A) and microphone via AVAudioEngine (CAF) simultaneously as separate files
2. **Merging**: Combines mic and system audio into a single file for transcription
3. **Transcription**: Sends merged audio to OpenAI's `gpt-4o-transcribe-diarize` API, which returns segments with speaker labels (A, B, C, etc.)
4. **Attribution**: Analyzes energy levels in the original separate files to determine mic vs system source; mic segments get your name, system segments keep their diarized speaker labels
5. **Speaker Renaming**: Presents a UI showing all speakers with sample text; user can rename any speaker or skip to keep defaults
6. **Formatting**: Collapses consecutive segments from the same speaker into turns, then outputs timestamped Markdown with speaker labels

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

MIT License - see [LICENSE](LICENSE) for details.
