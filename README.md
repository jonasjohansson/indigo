# Indigo

Native macOS app that turns any website into a Syphon + NDI video/audio source. Built for Resolume Arena and other VJ software.

Load a URL, click Start, and the web content appears as a source in Resolume — with audio over NDI.

## Features

- **Syphon output** — zero-copy GPU texture sharing via IOSurface
- **NDI output** — video + audio over the network
- **Viewport-only capture** — only the web content is sent, no app UI
- **Custom resolution** — 720p, 1080p, 4K, or any custom width/height
- **Custom CSS** — inject CSS to hide elements, change backgrounds, etc.
- **Audio capture** — web page audio sent over NDI (macOS 15+ requires Screen & System Audio Recording permission)
- **Settings persistence** — URL, resolution, CSS, and toggles remembered across sessions
- **Interactive** — browse, click, scroll the page while outputting

## Requirements

- macOS 13.0+ (Ventura or later)
- [NDI SDK for Apple](https://ndi.video/sdk/) installed at `/Library/NDI SDK for Apple/`
- Xcode (for building)
- Screen Recording permission (prompted on first launch)

## Build

```bash
bash build-app.sh
```

This builds a release binary and packages it as `Indigo.app` with the NDI dylib embedded.

## Run

```bash
# From terminal (shows debug logs):
Indigo.app/Contents/MacOS/Indigo

# Or double-click Indigo.app in Finder
```

## Usage

1. Launch Indigo
2. Enter a URL in the address bar and press Enter
3. Configure resolution and FPS in the settings panel (gear icon)
4. Toggle Syphon/NDI/Audio outputs as needed
5. Click **Start**
6. The web content appears as "Indigo" in Resolume's Syphon/NDI source list

## Architecture

```
WKWebView (renders page)
    |
    +-- Video stream (ScreenCaptureKit, window filter + sourceRect crop)
    |   +-> Syphon (IOSurface -> MTLTexture -> SyphonMetalServer)
    |   +-> NDI (CVPixelBuffer -> NDIlib_send_send_video_v2)
    |
    +-- Audio stream (ScreenCaptureKit, display filter for child process audio)
        +-> NDI (float32 deinterleave -> NDIlib_send_send_audio_v2)
```

Two ScreenCaptureKit streams run in parallel:
- **Video**: captures the app window with `sourceRect` cropping to exclude UI chrome, scaled to the configured output resolution
- **Audio**: uses a display filter scoped to the app to capture WKWebView's child process (WebContent) audio

## Dependencies

| Dependency | Purpose | Integration |
|---|---|---|
| [Syphon Framework](https://github.com/Syphon/Syphon-Framework) | GPU texture sharing | Vendored as CSyphon SPM target |
| [NDI SDK](https://ndi.video/sdk/) | Network video/audio | System install + bridging header |
| WebKit | Web rendering | System framework |
| Metal | GPU textures | System framework |
| ScreenCaptureKit | Window/audio capture | System framework |

## Permissions

On macOS 15 (Sequoia), Apple split screen recording into two separate permissions:
- **Screen Recording** — required for video capture
- **System Audio Recording** — required for audio capture

Grant both in **System Settings -> Privacy & Security -> Screen & System Audio Recording**.

## License

MIT
