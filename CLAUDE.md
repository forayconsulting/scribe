# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build (from Scribe/ directory)
swift build

# Build release
swift build -c release

# Copy release binary to app bundle for manual testing
cp .build/release/Scribe Scribe.app/Contents/MacOS/Scribe

# Run app
open Scribe.app
```

**Note:** When adding new Swift files, you must add them to the `sources` array in `Package.swift` - the build uses an explicit file list, not automatic discovery.

## Architecture Overview

Scribe is a macOS meeting transcription app that records both microphone and system audio simultaneously, then produces speaker-attributed transcripts.

### Core Flow (RecordingViewModel.swift)

1. **Recording**: `AudioCaptureService` captures system audio (ScreenCaptureKit → M4A) and mic (AVAudioEngine → CAF) as separate files
2. **Merge**: `AudioMerger` combines both tracks into a single audio file
3. **Transcribe**: `TranscriptionService` sends merged audio to OpenAI Whisper API (`whisper-1` with `verbose_json`)
4. **Attribute**: `AudioSourceAttributor` analyzes energy levels in the original separate files to determine which source each segment came from
5. **Format**: `MarkdownFormatter` collapses consecutive same-speaker segments into turns and outputs timestamped Markdown

### Why Merge-Then-Attribute?

Earlier approaches failed:
- Separate transcription: timestamps didn't align (different file timelines)
- Chunked transcription: quality degraded without full context
- Offset calculations: Whisper's timestamp handling is unpredictable

The current approach works because Whisper gets full context from the merged audio, and speaker attribution uses actual audio energy analysis rather than relying on Whisper's decisions.

### Key Services

- `AudioCaptureService`: Actor that manages dual audio capture via ScreenCaptureKit (system) and AVAudioEngine (mic)
- `TranscriptionService`: Actor for OpenAI Whisper API calls, handles chunking for files >25MB
- `AudioSourceAttributor`: Compares RMS energy at each segment's timestamp to attribute mic vs system

### Concurrency

The codebase uses Swift's strict concurrency (`StrictConcurrency` experimental feature enabled). Services like `AudioCaptureService`, `TranscriptionService`, and `AudioFileWriter` are actors.
