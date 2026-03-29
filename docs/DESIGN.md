# Indigo — Cross-Platform Design Document

Indigo turns any website into a live video+audio source for VJ and video production software.

## Architecture

```
WebView (renders page at any size)
│
├── Video capture (grabs WebView content only, excluding app UI)
│   ├── Crop to WebView bounds (sourceRect)
│   ├── Scale to configured output resolution (GPU blit)
│   ├→ GPU texture sharing (Syphon / Spout)
│   └→ Network streaming (NDI)
│
└── Audio capture (web page audio only)
    └→ NDI audio (float32, deinterleaved to planar)
```

## Core Concepts

### Output Resolution
- User configures width/height (e.g. 1920x1080)
- Presets: 720p (1280x720), 1080p (1920x1080), 4K (3840x2160)
- Custom resolutions supported via text input
- Output is always at the configured resolution, regardless of window size
- WebView content is scaled (GPU) to fit the output resolution

### Capture Pipeline
1. **Capture** the app window
2. **Crop** to the WebView bounds (exclude title bar, navigation, controls)
3. **Scale** to the configured output resolution
4. **Send** to enabled outputs (GPU texture sharing + NDI)

### Aspect Ratio
- While capturing, window resize is locked to the output aspect ratio
- This prevents distortion in the scaled output

### CSS Injection
- User can inject custom CSS into the loaded page
- Default: `body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; }`
- Applied after every navigation via script injection
- "Clear Cache" clears browsing data and reloads

### Settings Persistence
- All settings saved automatically on change
- Persisted values: URL, width, height, FPS, custom CSS, output toggles

## Output Protocols

### GPU Texture Sharing (Local)
- **macOS**: Syphon (IOSurface → Metal texture → SyphonMetalServer)
- **Windows**: Spout (DirectX 11 shared texture → SpoutDX)
- Zero-copy GPU path for lowest latency
- Receivers: Resolume Arena, VDMX, TouchDesigner, OBS

### NDI (Network)
- Cross-platform network video/audio streaming
- Video: BGRA pixel format, configurable frame rate (30/60fps)
- Audio: float32, deinterleaved from capture format to NDI planar format
- Uses synthesized timecode (server-side sync)
- Receivers: any NDI-compatible software on the network

### Audio
- Captures web page audio output
- Sent through NDI only (GPU texture sharing is video-only)
- Sample rate: 48kHz stereo (from system audio API)

## UI Layout

```
┌─────────────────────────────────────────────┐
│ ◀  ▶  ⟳  [ URL bar                    ] ⚙ │  Navigation bar
├─────────────────────────────────────────────┤
│ Width: [____] Height: [____] 720p 1080p 4K  │  Settings panel
│ CSS: [____________________________________] │  (collapsible)
│ [Clear Cache]                               │
├─────────────────────────────────────────────┤
│                                             │
│              WebView                        │  Main content
│           (interactive)                     │  (captured area)
│                                             │
├─────────────────────────────────────────────┤
│ [30/60fps] 1920x1080  [Syphon/Spout] [NDI] │  Control strip
│ [Audio] [Start/Stop]          status text   │
└─────────────────────────────────────────────┘
```

## Platform Implementation Map

| Feature | macOS | Windows |
|---------|-------|---------|
| Language | Swift / SwiftUI | C# / WPF (.NET 8) |
| Web engine | WKWebView | WebView2 (Chromium) |
| Window capture | ScreenCaptureKit | Windows.Graphics.Capture |
| GPU API | Metal | DirectX 11 |
| Texture sharing | Syphon | Spout (SpoutDX) |
| NDI | NDI SDK for Apple | NDI SDK for Windows |
| Audio capture | ScreenCaptureKit (display filter) | WASAPI loopback (NAudio) |
| Settings storage | NSUserDefaults | JSON (%AppData%/Indigo/) |
| Shader compilation | N/A (Metal built-in) | HLSL via D3DCompiler |
| Crop calculation | sourceRect on SCStream | DwmGetWindowAttribute + CopySubresourceRegion |
| Scaling | SCStream output dimensions | GPU blit (fullscreen triangle + bilinear sampler) |

## Key Implementation Details

### Video Frame Flow
```
macOS:  WKWebView → SCStream(sourceRect) → CVPixelBuffer → Syphon/NDI
Windows: WebView2 → GraphicsCapture → Crop(CopySubresourceRegion) → Scale(GPU blit) → Spout/NDI
```

### Audio Deinterleaving (both platforms)
The system audio API delivers interleaved float32 samples. NDI v2 expects planar format:
```
Interleaved: [L0, R0, L1, R1, L2, R2, ...]
Planar:      [L0, L1, L2, ...], [R0, R1, R2, ...]

for channel in 0..<channelCount:
    for sample in 0..<sampleCount:
        planar[channel * sampleCount + sample] = interleaved[sample * channelCount + channel]
```

### Thread Safety
- Capture callbacks arrive on background threads
- GPU device context access must be thread-safe
  - macOS: Metal command buffers are thread-safe
  - Windows: Enable `ID3D11Multithread` protection on DX11 device

## Build & Distribution

### macOS
- Swift Package Manager
- `build-app.sh` creates .app bundle with embedded NDI dylib
- Requires: Xcode, NDI SDK at `/Library/NDI SDK for Apple/`

### Windows
- .NET 8 / MSBuild
- `build.ps1` publishes self-contained exe with native DLLs
- Requires: .NET 8 SDK, NDI Runtime, SpoutDX.dll
