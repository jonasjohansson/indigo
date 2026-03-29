# Indigo for Windows — Design Document

## Summary

Port Indigo (macOS app that turns websites into live Spout/NDI video+audio sources) to Windows using C#/WPF, WebView2, DirectX 11, Spout, and NDI.

## Architecture

```
WebView2 (Composition Mode, renders to DirectX 11 swap chain)
│
├── Video path
│   ├── DirectX 11 shared texture → Spout sender (zero-copy GPU)
│   └── Texture → CPU readback → NDI video frame
│
└── Audio path (WASAPI loopback on WebView2 process)
    └── Float32 PCM → NDI audio frame
```

## Tech Stack

- **Language**: C# / .NET 8
- **UI Framework**: WPF
- **Web Engine**: WebView2 (Composition Mode)
- **GPU**: DirectX 11 (SharpDX or Vortice.Windows for managed interop)
- **Video Sharing**: Spout (SpoutDX SDK)
- **Network Streaming**: NDI SDK
- **Audio Capture**: WASAPI via NAudio

## Project Structure

```
indigo-windows/
├── IndigoWindows.sln
├── IndigoWindows/
│   ├── App.xaml / App.xaml.cs          — WPF app entry
│   ├── MainWindow.xaml / .cs           — UI (URL bar, settings, controls)
│   ├── WebViewHost.cs                  — WebView2 composition setup
│   ├── FrameCapture.cs                 — Extract DX11 texture each frame
│   ├── SpoutOutput.cs                  — Spout sender (DX11 shared texture)
│   ├── NdiOutput.cs                    — NDI sender (video + audio)
│   ├── AudioCapture.cs                 — WASAPI loopback for page audio
│   └── Settings.cs                     — User settings persistence
├── libs/
│   ├── SpoutDX/                        — Spout SDK binaries
│   └── NDI/                            — NDI SDK binaries
└── README.md
```

## Video Pipeline

1. **WebView2 Composition Mode**: Initialize with `CreateCoreWebView2CompositionController` to render into a DirectX swap chain.
2. **Frame Extraction**: Each frame (at configured FPS), get the back buffer as `ID3D11Texture2D` from the swap chain.
3. **Spout Output**: Share the DX11 texture directly via SpoutDX sender — zero-copy GPU path.
4. **NDI Output**: Copy GPU texture to staging texture (CPU readback), wrap BGRA buffer as `NDIlib_video_frame_v2_t`, send via `NDIlib_send_send_video_v2`.

## Audio Pipeline

1. **WASAPI Loopback**: Capture audio from the WebView2 renderer process using NAudio's WASAPI loopback capture.
2. **NDI Audio**: Convert interleaved float32 samples to NDI format, send via `NDIlib_send_send_audio_v2`.

## UI

Matches macOS Indigo layout:
- URL bar with back/forward/reload
- Collapsible settings: resolution (width/height), FPS, custom CSS injection
- Control strip: Spout toggle, NDI toggle, Audio toggle, Start/Stop
- WebView2 fills the main area (interactive)

## Settings

JSON file in `%AppData%/Indigo/settings.json` persisting: URL, width, height, FPS, custom CSS, toggle states.

## Dependencies

| Package | Source | Purpose |
|---------|--------|---------|
| Microsoft.Web.WebView2 | NuGet | Chromium web view |
| Vortice.Windows | NuGet | DirectX 11 managed interop |
| NAudio | NuGet | WASAPI audio capture |
| SpoutDX | Vendored | GPU texture sharing |
| NDI SDK | Vendored/System | Network video streaming |

## Platform Requirements

- Windows 10 1903+ (for WebView2 and Windows.Graphics.Capture)
- .NET 8 runtime
- WebView2 Runtime (pre-installed on Windows 11, downloadable for Windows 10)
- NDI Runtime (for NDI output)
