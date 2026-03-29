# Indigo

Turn any website into a live video/audio source for VJ and video production software.

Load a URL, click Start, and the web content appears as a source in Resolume Arena, OBS, or any Syphon/Spout/NDI receiver — with audio over NDI.

Available for **macOS** and **Windows**.

## Features

- **GPU texture sharing** — Syphon (macOS) / Spout (Windows)
- **NDI output** — video + audio over the network
- **Viewport-only capture** — only the web content is sent, no app UI
- **Custom resolution** — 720p, 1080p, 4K, or any custom width/height
- **Custom CSS** — inject CSS to hide elements, change backgrounds, etc.
- **Audio capture** — web page audio sent over NDI
- **Settings persistence** — URL, resolution, CSS, and toggles remembered across sessions
- **Interactive** — browse, click, scroll the page while outputting
- **Aspect ratio lock** — window resize locked to output ratio while capturing

## Project Structure

```
indigo/
├── macos/          macOS app (Swift / SwiftUI)
├── windows/        Windows app (C# / WPF / .NET 8)
├── assets/         Shared icons (icns, ico, png)
├── docs/           Design docs and plans
└── README.md
```

## macOS

### Requirements
- macOS 13.0+ (Ventura or later)
- [NDI SDK for Apple](https://ndi.video/sdk/) at `/Library/NDI SDK for Apple/`
- Xcode
- Screen Recording + System Audio Recording permissions

### Build & Run
```bash
cd macos
bash build-app.sh
open Indigo.app
```

### Architecture
```
WKWebView → ScreenCaptureKit (sourceRect crop + scaling)
├→ Syphon (IOSurface → Metal → SyphonMetalServer)
├→ NDI video (CVPixelBuffer → BGRA)
└→ NDI audio (float32 deinterleave → planar)
```

## Windows

### Requirements
- Windows 10 1903+ / Windows 11
- .NET 8 SDK
- [NDI Runtime](https://ndi.video/tools/)
- WebView2 Runtime (pre-installed on Windows 11)

### Build & Run
```bash
cd windows
dotnet run --project IndigoWindows
```

Or build a release:
```powershell
cd windows
pwsh build.ps1
./publish/Indigo.exe
```

### Architecture
```
WebView2 → Windows.Graphics.Capture (crop + GPU scale)
├→ Spout (DirectX 11 shared texture via SpoutDX)
├→ NDI video (staging texture readback → BGRA)
└→ NDI audio (WASAPI loopback → float32 deinterleave → planar)
```

## Usage

1. Launch Indigo
2. Enter a URL and press Enter
3. Configure resolution and FPS (gear icon)
4. Toggle outputs (Syphon/Spout, NDI, Audio)
5. Click **Start**
6. Web content appears as "Indigo" in your VJ software

## Future

- **Process-specific audio** (Windows) — currently captures all system audio via WASAPI loopback; should isolate WebView2 process audio only (WASAPI process loopback, Windows 10 2004+)
- **Frame rate throttling** — capture runs at monitor refresh rate; should drop/skip frames to match the configured 30/60fps setting
- **macOS build paths** — Package.swift needs updating after repo restructure (Sources/ → macos/Sources/)
- **Spout stability** — P/Invoke uses C++ mangled names from prebuilt SpoutDX.dll; consider building a thin C wrapper for version resilience
- **Transparent background** — pass through alpha channel for overlay compositing
- **Multiple sources** — support multiple URLs/tabs as separate outputs
- **MIDI/OSC control** — remote control of URL, start/stop, resolution from VJ software

## Design

See [docs/DESIGN.md](docs/DESIGN.md) for the cross-platform design document.

## License

MIT
