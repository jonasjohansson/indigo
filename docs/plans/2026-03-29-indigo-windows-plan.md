# Indigo for Windows — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Port Indigo to Windows — a WPF app that loads any website via WebView2 and outputs live video+audio via Spout (GPU texture sharing) and NDI (network streaming).

**Architecture:** WebView2 in composition mode renders to a DirectX 11 swap chain. Each frame, we extract the DX11 texture and share it via Spout (zero-copy GPU) and/or NDI (CPU readback → BGRA buffer). Audio is captured via WASAPI loopback and sent through NDI.

**Tech Stack:** C# / .NET 8 / WPF, WebView2, Vortice.Windows (DX11 interop), SpoutDX, NDI SDK, NAudio

---

### Task 1: Scaffold the .NET 8 WPF Project

**Files:**
- Create: `indigo-windows/IndigoWindows.sln`
- Create: `indigo-windows/IndigoWindows/IndigoWindows.csproj`
- Create: `indigo-windows/IndigoWindows/App.xaml`
- Create: `indigo-windows/IndigoWindows/App.xaml.cs`
- Create: `indigo-windows/IndigoWindows/MainWindow.xaml`
- Create: `indigo-windows/IndigoWindows/MainWindow.xaml.cs`

**Step 1: Create the project using dotnet CLI**

```bash
cd indigo-windows
dotnet new wpf -n IndigoWindows --framework net8.0
dotnet new sln -n IndigoWindows
dotnet sln add IndigoWindows/IndigoWindows.csproj
```

**Step 2: Add NuGet dependencies**

```bash
cd IndigoWindows
dotnet add package Microsoft.Web.WebView2
dotnet add package Vortice.Direct3D11
dotnet add package Vortice.DXGI
dotnet add package NAudio
dotnet add package Newtonsoft.Json
```

**Step 3: Verify it builds**

```bash
dotnet build
```
Expected: Build succeeded.

**Step 4: Commit**

```bash
git add indigo-windows/
git commit -m "feat(windows): scaffold .NET 8 WPF project with dependencies"
```

---

### Task 2: Settings Persistence

**Files:**
- Create: `indigo-windows/IndigoWindows/Settings.cs`

**Step 1: Implement AppSettings class**

```csharp
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using Newtonsoft.Json;

namespace IndigoWindows;

public class AppSettings : INotifyPropertyChanged
{
    private static readonly string SettingsDir =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Indigo");
    private static readonly string SettingsPath = Path.Combine(SettingsDir, "settings.json");

    private string _url = "https://example.com";
    private int _width = 1920;
    private int _height = 1080;
    private int _fps = 60;
    private string _customCSS = "body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; }";
    private bool _spoutEnabled = true;
    private bool _ndiEnabled = true;
    private bool _audioEnabled = true;

    public string Url { get => _url; set => SetField(ref _url, value); }
    public int Width { get => _width; set => SetField(ref _width, value); }
    public int Height { get => _height; set => SetField(ref _height, value); }
    public int Fps { get => _fps; set => SetField(ref _fps, value); }
    public string CustomCSS { get => _customCSS; set => SetField(ref _customCSS, value); }
    public bool SpoutEnabled { get => _spoutEnabled; set => SetField(ref _spoutEnabled, value); }
    public bool NdiEnabled { get => _ndiEnabled; set => SetField(ref _ndiEnabled, value); }
    public bool AudioEnabled { get => _audioEnabled; set => SetField(ref _audioEnabled, value); }

    public event PropertyChangedEventHandler? PropertyChanged;

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (Equals(field, value)) return false;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        Save();
        return true;
    }

    public void Save()
    {
        Directory.CreateDirectory(SettingsDir);
        File.WriteAllText(SettingsPath, JsonConvert.SerializeObject(this, Formatting.Indented));
    }

    public static AppSettings Load()
    {
        if (!File.Exists(SettingsPath)) return new AppSettings();
        try
        {
            var json = File.ReadAllText(SettingsPath);
            return JsonConvert.DeserializeObject<AppSettings>(json) ?? new AppSettings();
        }
        catch { return new AppSettings(); }
    }
}
```

**Step 2: Verify it builds**

```bash
dotnet build
```

**Step 3: Commit**

```bash
git add indigo-windows/IndigoWindows/Settings.cs
git commit -m "feat(windows): add settings persistence with JSON storage"
```

---

### Task 3: Main Window UI (XAML)

**Files:**
- Modify: `indigo-windows/IndigoWindows/MainWindow.xaml`
- Modify: `indigo-windows/IndigoWindows/MainWindow.xaml.cs`

**Step 1: Create the XAML layout matching macOS Indigo**

```xml
<Window x:Class="IndigoWindows.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:wv2="clr-namespace:Microsoft.Web.WebView2.Wpf;assembly=Microsoft.Web.WebView2.Wpf"
        Title="Indigo" Width="800" Height="600" MinWidth="640" MinHeight="480"
        Background="#1E1E1E" WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <Style x:Key="ToolBtn" TargetType="Button">
            <Setter Property="Background" Value="#2D2D2D"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style x:Key="ToggleStyle" TargetType="ToggleButton">
            <Setter Property="Background" Value="#2D2D2D"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#444"/>
            <Setter Property="Padding" Value="10,4"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsChecked" Value="True">
                    <Setter Property="Background" Value="#0078D4"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <DockPanel>
        <!-- Navigation Bar -->
        <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Background="#252526" Height="36">
            <Button Content="◀" Style="{StaticResource ToolBtn}" Click="Back_Click" Width="32"/>
            <Button Content="▶" Style="{StaticResource ToolBtn}" Click="Forward_Click" Width="32"/>
            <Button Content="⟳" Style="{StaticResource ToolBtn}" Click="Reload_Click" Width="32"/>
            <TextBox x:Name="UrlBar" VerticalContentAlignment="Center" Margin="4,4"
                     Background="#3C3C3C" Foreground="#CCCCCC" BorderThickness="0"
                     FontSize="13" KeyDown="UrlBar_KeyDown"
                     Text="{Binding Url, UpdateSourceTrigger=PropertyChanged}"/>
            <Button Content="⚙" Style="{StaticResource ToolBtn}" Click="ToggleSettings_Click" Width="32"/>
        </StackPanel>

        <!-- Settings Panel (collapsible) -->
        <StackPanel x:Name="SettingsPanel" DockPanel.Dock="Top" Background="#2D2D2D"
                    Visibility="Collapsed" Margin="0">
            <StackPanel Orientation="Horizontal" Margin="8,6">
                <TextBlock Text="Width:" Foreground="#AAA" VerticalAlignment="Center" Margin="0,0,4,0"/>
                <TextBox x:Name="WidthBox" Width="60" Background="#3C3C3C" Foreground="#CCC"
                         BorderThickness="0" Padding="4,2"
                         Text="{Binding Width, UpdateSourceTrigger=LostFocus}"/>
                <TextBlock Text="Height:" Foreground="#AAA" VerticalAlignment="Center" Margin="12,0,4,0"/>
                <TextBox x:Name="HeightBox" Width="60" Background="#3C3C3C" Foreground="#CCC"
                         BorderThickness="0" Padding="4,2"
                         Text="{Binding Height, UpdateSourceTrigger=LostFocus}"/>
                <Button Content="720p" Style="{StaticResource ToolBtn}" Click="Preset720_Click" Margin="8,0,2,0"/>
                <Button Content="1080p" Style="{StaticResource ToolBtn}" Click="Preset1080_Click" Margin="2,0"/>
                <Button Content="4K" Style="{StaticResource ToolBtn}" Click="Preset4K_Click" Margin="2,0"/>
            </StackPanel>
            <StackPanel Orientation="Horizontal" Margin="8,0,8,6">
                <TextBlock Text="CSS:" Foreground="#AAA" VerticalAlignment="Center" Margin="0,0,4,0"/>
                <TextBox x:Name="CSSBox" Background="#3C3C3C" Foreground="#CCC" BorderThickness="0"
                         Padding="4,2" MinWidth="400"
                         Text="{Binding CustomCSS, UpdateSourceTrigger=LostFocus}"/>
                <Button Content="Clear Cache" Style="{StaticResource ToolBtn}" Click="ClearCache_Click" Margin="8,0,0,0"/>
            </StackPanel>
        </StackPanel>

        <!-- Control Strip -->
        <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" Background="#252526"
                    Height="36" VerticalAlignment="Center">
            <ComboBox x:Name="FpsPicker" Width="65" Margin="8,4" VerticalContentAlignment="Center"
                      SelectionChanged="Fps_Changed">
                <ComboBoxItem Content="30 fps"/>
                <ComboBoxItem Content="60 fps"/>
            </ComboBox>
            <TextBlock x:Name="ResLabel" Foreground="#888" VerticalAlignment="Center"
                       FontFamily="Consolas" FontSize="12" Margin="8,0"/>
            <ToggleButton x:Name="SpoutToggle" Content="Spout" Style="{StaticResource ToggleStyle}"
                          IsChecked="{Binding SpoutEnabled}" Margin="8,4,2,4"/>
            <ToggleButton x:Name="NdiToggle" Content="NDI" Style="{StaticResource ToggleStyle}"
                          IsChecked="{Binding NdiEnabled}" Margin="2,4"/>
            <ToggleButton x:Name="AudioToggle" Content="Audio" Style="{StaticResource ToggleStyle}"
                          IsChecked="{Binding AudioEnabled}" Margin="2,4"/>
            <Button x:Name="StartStopBtn" Content="Start" Style="{StaticResource ToolBtn}"
                    Click="StartStop_Click" Margin="8,4" FontWeight="Bold"
                    Background="#2EA043" Foreground="White" Padding="16,4"/>
            <TextBlock x:Name="StatusText" Foreground="#FF6B6B" VerticalAlignment="Center"
                       Margin="8,0" FontSize="12"/>
        </StackPanel>

        <!-- WebView2 -->
        <wv2:WebView2 x:Name="WebView" DockPanel.Dock="Top"/>
    </DockPanel>
</Window>
```

**Step 2: Implement the code-behind**

```csharp
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Web.WebView2.Core;

namespace IndigoWindows;

public partial class MainWindow : Window
{
    private readonly AppSettings _settings;
    private bool _isCapturing;

    public MainWindow()
    {
        _settings = AppSettings.Load();
        DataContext = _settings;
        InitializeComponent();

        FpsPicker.SelectedIndex = _settings.Fps == 30 ? 0 : 1;
        UpdateResLabel();
        Loaded += async (_, _) => await InitWebView();
    }

    private async Task InitWebView()
    {
        await WebView.EnsureCoreWebView2Async();
        WebView.CoreWebView2.Settings.AreDevToolsEnabled = true;
        NavigateToUrl();
    }

    private void NavigateToUrl()
    {
        var url = _settings.Url;
        if (!url.StartsWith("http://") && !url.StartsWith("https://"))
            url = "https://" + url;
        _settings.Url = url;
        WebView.CoreWebView2?.Navigate(url);
        InjectCSS();
    }

    private async void InjectCSS()
    {
        if (WebView.CoreWebView2 == null || string.IsNullOrWhiteSpace(_settings.CustomCSS)) return;
        var script = $"var s=document.createElement('style');s.textContent=`{_settings.CustomCSS}`;document.head.appendChild(s);";
        await WebView.CoreWebView2.ExecuteScriptAsync(script);
    }

    private void UrlBar_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
        {
            NavigateToUrl();
            WebView.Focus();
        }
    }

    private void Back_Click(object sender, RoutedEventArgs e) => WebView.CoreWebView2?.GoBack();
    private void Forward_Click(object sender, RoutedEventArgs e) => WebView.CoreWebView2?.GoForward();
    private void Reload_Click(object sender, RoutedEventArgs e) => WebView.CoreWebView2?.Reload();

    private void ToggleSettings_Click(object sender, RoutedEventArgs e)
    {
        SettingsPanel.Visibility = SettingsPanel.Visibility == Visibility.Visible
            ? Visibility.Collapsed : Visibility.Visible;
    }

    private void Preset720_Click(object sender, RoutedEventArgs e) { _settings.Width = 1280; _settings.Height = 720; UpdateResLabel(); }
    private void Preset1080_Click(object sender, RoutedEventArgs e) { _settings.Width = 1920; _settings.Height = 1080; UpdateResLabel(); }
    private void Preset4K_Click(object sender, RoutedEventArgs e) { _settings.Width = 3840; _settings.Height = 2160; UpdateResLabel(); }

    private void Fps_Changed(object sender, SelectionChangedEventArgs e)
    {
        _settings.Fps = FpsPicker.SelectedIndex == 0 ? 30 : 60;
    }

    private void UpdateResLabel()
    {
        ResLabel.Text = $"{_settings.Width}×{_settings.Height}";
    }

    private async void ClearCache_Click(object sender, RoutedEventArgs e)
    {
        if (WebView.CoreWebView2 == null) return;
        await WebView.CoreWebView2.Profile.ClearBrowsingDataAsync();
        WebView.CoreWebView2.Reload();
    }

    private void StartStop_Click(object sender, RoutedEventArgs e)
    {
        // Placeholder — wired up in Task 7 (OutputManager)
        _isCapturing = !_isCapturing;
        StartStopBtn.Content = _isCapturing ? "Stop" : "Start";
        StartStopBtn.Background = _isCapturing
            ? System.Windows.Media.Brushes.Crimson
            : new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(0x2E, 0xA0, 0x43));
    }
}
```

**Step 3: Make the URL bar stretch to fill available space**

In the XAML NavigationBar StackPanel, replace the UrlBar `TextBox` with a `DockPanel` parent approach: change the navigation bar from `StackPanel` to `DockPanel` so the TextBox fills remaining space.

Replace the navigation bar section:
```xml
<DockPanel DockPanel.Dock="Top" Background="#252526" Height="36">
    <Button Content="◀" Style="{StaticResource ToolBtn}" Click="Back_Click" Width="32" DockPanel.Dock="Left"/>
    <Button Content="▶" Style="{StaticResource ToolBtn}" Click="Forward_Click" Width="32" DockPanel.Dock="Left"/>
    <Button Content="⟳" Style="{StaticResource ToolBtn}" Click="Reload_Click" Width="32" DockPanel.Dock="Left"/>
    <Button Content="⚙" Style="{StaticResource ToolBtn}" Click="ToggleSettings_Click" Width="32" DockPanel.Dock="Right"/>
    <TextBox x:Name="UrlBar" VerticalContentAlignment="Center" Margin="4,4"
             Background="#3C3C3C" Foreground="#CCCCCC" BorderThickness="0"
             FontSize="13" KeyDown="UrlBar_KeyDown"
             Text="{Binding Url, UpdateSourceTrigger=PropertyChanged}"/>
</DockPanel>
```

**Step 4: Verify it builds and runs**

```bash
dotnet build
dotnet run
```
Expected: Window appears with dark UI, URL bar, WebView2 loads example.com, settings panel toggles, Start/Stop button toggles color.

**Step 5: Commit**

```bash
git add indigo-windows/IndigoWindows/MainWindow.xaml indigo-windows/IndigoWindows/MainWindow.xaml.cs
git commit -m "feat(windows): main window UI with navigation, settings, and controls"
```

---

### Task 4: WebView2 Frame Capture via PrintToBitmapAsync

**Files:**
- Create: `indigo-windows/IndigoWindows/FrameCapture.cs`

**Context:** WebView2's composition mode requires complex interop with `ICoreWebView2CompositionController` and DirectX swap chain access which isn't well-supported in the managed WPF control. A more reliable approach for v1 is to use `CapturePreviewAsync` or the `PrintToBitmapAsync` API — but these are too slow for real-time.

**Revised approach:** Use `Windows.Graphics.Capture` (WinRT) to capture the WebView2 window content at high frame rate. This mirrors the macOS ScreenCaptureKit approach and is well-tested in production (OBS, etc.).

**Step 1: Add WinRT projection packages**

```bash
cd indigo-windows/IndigoWindows
dotnet add package Microsoft.Windows.SDK.Contracts
dotnet add package System.Drawing.Common
```

Also update `.csproj` to target `net8.0-windows10.0.19041.0`:
```xml
<TargetFramework>net8.0-windows10.0.19041.0</TargetFramework>
```

**Step 2: Implement FrameCapture using Windows.Graphics.Capture**

```csharp
using System;
using System.Runtime.InteropServices;
using System.Threading;
using Vortice.Direct3D;
using Vortice.Direct3D11;
using Vortice.DXGI;
using Windows.Graphics;
using Windows.Graphics.Capture;
using Windows.Graphics.DirectX;
using Windows.Graphics.DirectX.Direct3D11;

namespace IndigoWindows;

public class FrameCapture : IDisposable
{
    public delegate void FrameHandler(ID3D11Texture2D texture, int width, int height);
    public event FrameHandler? OnFrame;

    private readonly ID3D11Device _device;
    private readonly ID3D11DeviceContext _context;
    private GraphicsCaptureItem? _captureItem;
    private Direct3D11CaptureFramePool? _framePool;
    private GraphicsCaptureSession? _session;
    private IDirect3DDevice? _winrtDevice;
    private SizeInt32 _lastSize;
    private bool _disposed;

    public ID3D11Device Device => _device;
    public ID3D11DeviceContext Context => _context;

    public FrameCapture()
    {
        D3D11.D3D11CreateDevice(
            null, DriverType.Hardware, DeviceCreationFlags.BgraSupport,
            new[] { FeatureLevel.Level_11_0 }, out _device!, out _context!);
    }

    public void StartCapture(IntPtr hwnd, int width, int height)
    {
        _captureItem = CaptureHelper.CreateItemForWindow(hwnd);
        if (_captureItem == null) throw new InvalidOperationException("Cannot create capture item for window.");

        _winrtDevice = CaptureHelper.CreateDirect3DDeviceFromD3D11(_device);
        _lastSize = _captureItem.Size;

        _framePool = Direct3D11CaptureFramePool.CreateFreeThreaded(
            _winrtDevice, DirectXPixelFormat.B8G8R8A8UIntNormalized, 2, _captureItem.Size);

        _framePool.FrameArrived += OnFrameArrived;
        _session = _framePool.CreateCaptureSession(_captureItem);
        _session.IsBorderRequired = false;
        _session.IsCursorCaptureEnabled = false;
        _session.StartCapture();
    }

    private void OnFrameArrived(Direct3D11CaptureFramePool sender, object args)
    {
        using var frame = sender.TryGetNextFrame();
        if (frame == null) return;

        var texture = CaptureHelper.GetTextureFromSurface(frame.Surface, _device);
        if (texture == null) return;

        OnFrame?.Invoke(texture, frame.ContentSize.Width, frame.ContentSize.Height);
    }

    public void StopCapture()
    {
        _session?.Dispose();
        _framePool?.Dispose();
        _session = null;
        _framePool = null;
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        StopCapture();
        _context?.Dispose();
        _device?.Dispose();
    }
}
```

**Step 3: Create the WinRT/COM interop helper**

Create `indigo-windows/IndigoWindows/CaptureHelper.cs`:

```csharp
using System;
using System.Runtime.InteropServices;
using Vortice.Direct3D11;
using Vortice.DXGI;
using Windows.Graphics.Capture;
using Windows.Graphics.DirectX.Direct3D11;
using WinRT;

namespace IndigoWindows;

public static class CaptureHelper
{
    [DllImport("d3d11.dll", EntryPoint = "CreateDirect3D11DeviceFromDXGIDevice",
        SetLastError = true, CharSet = CharSet.Unicode, ExactSpelling = true,
        CallingConvention = CallingConvention.StdCall)]
    private static extern int CreateDirect3D11DeviceFromDXGIDevice(IntPtr dxgiDevice, out IntPtr graphicsDevice);

    [ComImport]
    [Guid("A9B3D012-3DF2-4EE3-B8D1-8695F457D3C1")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IDirect3DDxgiInterfaceAccess
    {
        IntPtr GetInterface([In] ref Guid iid);
    }

    public static GraphicsCaptureItem? CreateItemForWindow(IntPtr hwnd)
    {
        var factory = WinRT.GraphicsCapture.GraphicsCaptureItemInterop.GetInstance();
        return factory?.CreateForWindow(hwnd);
    }

    public static IDirect3DDevice? CreateDirect3DDeviceFromD3D11(ID3D11Device d3d11Device)
    {
        using var dxgiDevice = d3d11Device.QueryInterface<IDXGIDevice>();
        int hr = CreateDirect3D11DeviceFromDXGIDevice(dxgiDevice.NativePointer, out var pUnk);
        if (hr != 0) return null;
        return MarshalInterface<IDirect3DDevice>.FromAbi(pUnk);
    }

    public static ID3D11Texture2D? GetTextureFromSurface(IDirect3DSurface surface, ID3D11Device device)
    {
        var access = (IDirect3DDxgiInterfaceAccess)(object)surface;
        var iid = typeof(ID3D11Texture2D).GUID;
        var ptr = access.GetInterface(ref iid);
        return new ID3D11Texture2D(ptr);
    }
}
```

> **Note:** The WinRT interop for `GraphicsCaptureItem.CreateForWindow` varies by .NET version. The exact interop code may need adjustment based on the WinRT projection package used. Check docs during implementation.

**Step 4: Verify it builds**

```bash
dotnet build
```

**Step 5: Commit**

```bash
git add indigo-windows/IndigoWindows/FrameCapture.cs indigo-windows/IndigoWindows/CaptureHelper.cs
git commit -m "feat(windows): frame capture using Windows.Graphics.Capture API"
```

---

### Task 5: Spout Output

**Files:**
- Create: `indigo-windows/IndigoWindows/SpoutOutput.cs`
- Create: `indigo-windows/libs/SpoutDX/` (vendored SDK)

**Step 1: Download and vendor SpoutDX**

Download the SpoutDX SDK from https://github.com/leadedge/Spout2. We need:
- `SpoutDX.dll` (native DLL)
- Or use the SpoutDX C++ API via P/Invoke

The simplest path is to use the **SpoutLibrary** DLL which provides a C-compatible API.

**Step 2: Create P/Invoke wrapper**

```csharp
using System;
using System.Runtime.InteropServices;
using Vortice.Direct3D11;

namespace IndigoWindows;

public class SpoutOutput : IDisposable
{
    // SpoutDX uses a COM-like interface. For simplicity, we use the C-compatible SpoutLibrary.
    // Alternative: use the Spout SDK NuGet if available, or wrap SpoutDX.h via C++/CLI.

    [DllImport("SpoutLibrary.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr CreateSender(string name, int width, int height);

    [DllImport("SpoutLibrary.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern bool SendTexture(IntPtr sender, IntPtr sharedTextureHandle);

    [DllImport("SpoutLibrary.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern void ReleaseSender(IntPtr sender);

    private IntPtr _sender;
    private string _name = "";
    private bool _disposed;

    public bool IsRunning => _sender != IntPtr.Zero;

    public void Start(string name, int width, int height)
    {
        _name = name;
        _sender = CreateSender(name, width, height);
    }

    public void SendFrame(ID3D11Texture2D texture)
    {
        if (_sender == IntPtr.Zero) return;
        // Get the shared handle from the DX11 texture for Spout
        using var resource = texture.QueryInterface<IDXGIResource>();
        var handle = resource.SharedHandle;
        SendTexture(_sender, handle);
    }

    public void Stop()
    {
        if (_sender != IntPtr.Zero)
        {
            ReleaseSender(_sender);
            _sender = IntPtr.Zero;
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        Stop();
    }
}
```

> **Note:** The exact Spout API depends on which library variant is used. The SpoutDX C++ library, SpoutLibrary C DLL, or the Spout.NET NuGet wrapper are all options. During implementation, choose the most practical one and adjust the P/Invoke signatures. The key operation is: create sender → send DX11 shared texture handle → release sender.

**Step 3: Verify it builds** (may need stubs if DLLs aren't available yet)

```bash
dotnet build
```

**Step 4: Commit**

```bash
git add indigo-windows/IndigoWindows/SpoutOutput.cs indigo-windows/libs/SpoutDX/
git commit -m "feat(windows): Spout output via SpoutDX shared texture"
```

---

### Task 6: NDI Output

**Files:**
- Create: `indigo-windows/IndigoWindows/NdiOutput.cs`
- Create: `indigo-windows/IndigoWindows/NdiInterop.cs`

**Step 1: Create NDI P/Invoke interop**

```csharp
using System;
using System.Runtime.InteropServices;

namespace IndigoWindows;

public static class NdiInterop
{
    private const string NdiLib = "Processing.NDI.Lib.x64.dll";

    [StructLayout(LayoutKind.Sequential)]
    public struct NDIlib_send_create_t
    {
        [MarshalAs(UnmanagedType.LPStr)] public string p_ndi_name;
        [MarshalAs(UnmanagedType.LPStr)] public string? p_groups;
        [MarshalAs(UnmanagedType.Bool)] public bool clock_video;
        [MarshalAs(UnmanagedType.Bool)] public bool clock_audio;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct NDIlib_video_frame_v2_t
    {
        public int xres, yres;
        public int FourCC;          // NDIlib_FourCC_video_type_BGRA = 0x41524742
        public int frame_rate_N, frame_rate_D;
        public float picture_aspect_ratio;
        public int frame_format_type; // 1 = progressive
        public long timecode;        // NDIlib_send_timecode_synthesize = Int64.MaxValue
        public IntPtr p_data;
        public int line_stride_in_bytes;
        public IntPtr p_metadata;
        public long timestamp;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct NDIlib_audio_frame_v2_t
    {
        public int sample_rate;
        public int no_channels;
        public int no_samples;
        public long timecode;
        public IntPtr p_data;
        public int channel_stride_in_bytes;
        public IntPtr p_metadata;
        public long timestamp;
    }

    [DllImport(NdiLib)] public static extern bool NDIlib_initialize();
    [DllImport(NdiLib)] public static extern void NDIlib_destroy();
    [DllImport(NdiLib)] public static extern IntPtr NDIlib_send_create(ref NDIlib_send_create_t settings);
    [DllImport(NdiLib)] public static extern void NDIlib_send_destroy(IntPtr instance);
    [DllImport(NdiLib)] public static extern void NDIlib_send_send_video_v2(IntPtr instance, ref NDIlib_video_frame_v2_t frame);
    [DllImport(NdiLib)] public static extern void NDIlib_send_send_audio_v2(IntPtr instance, ref NDIlib_audio_frame_v2_t frame);

    public const int NDIlib_FourCC_video_type_BGRA = 0x41524742; // 'BARG' in little-endian
    public const long NDIlib_send_timecode_synthesize = long.MaxValue;
}
```

**Step 2: Implement NdiOutput**

```csharp
using System;
using System.Runtime.InteropServices;
using Vortice.Direct3D11;
using Vortice.DXGI;

namespace IndigoWindows;

public class NdiOutput : IDisposable
{
    private IntPtr _sender;
    private bool _initialized;
    private bool _disposed;
    private ID3D11Texture2D? _stagingTexture;
    private ID3D11Device? _device;
    private ID3D11DeviceContext? _context;

    public bool IsRunning => _sender != IntPtr.Zero;

    public void Start(string name, ID3D11Device device, ID3D11DeviceContext context)
    {
        _device = device;
        _context = context;

        if (!_initialized)
        {
            _initialized = NdiInterop.NDIlib_initialize();
            if (!_initialized) throw new Exception("Failed to initialize NDI.");
        }

        var settings = new NdiInterop.NDIlib_send_create_t
        {
            p_ndi_name = name,
            clock_video = true,
            clock_audio = true
        };
        _sender = NdiInterop.NDIlib_send_create(ref settings);
    }

    public void SendVideoFrame(ID3D11Texture2D sourceTexture, int width, int height)
    {
        if (_sender == IntPtr.Zero || _device == null || _context == null) return;

        // Create or recreate staging texture if size changed
        EnsureStagingTexture(width, height);

        // Copy GPU texture to CPU-readable staging texture
        _context.CopyResource(_stagingTexture!, sourceTexture);
        var mapped = _context.Map(_stagingTexture!, 0, MapMode.Read);

        try
        {
            var frame = new NdiInterop.NDIlib_video_frame_v2_t
            {
                xres = width,
                yres = height,
                FourCC = NdiInterop.NDIlib_FourCC_video_type_BGRA,
                frame_rate_N = 60000,
                frame_rate_D = 1000,
                picture_aspect_ratio = (float)width / height,
                frame_format_type = 1, // progressive
                timecode = NdiInterop.NDIlib_send_timecode_synthesize,
                p_data = mapped.DataPointer,
                line_stride_in_bytes = mapped.RowPitch
            };

            NdiInterop.NDIlib_send_send_video_v2(_sender, ref frame);
        }
        finally
        {
            _context.Unmap(_stagingTexture!, 0);
        }
    }

    public void SendAudioFrame(float[] interleaved, int sampleRate, int channels, int sampleCount)
    {
        if (_sender == IntPtr.Zero) return;

        // Deinterleave: [L0,R0,L1,R1,...] → [L0,L1,...,R0,R1,...]
        var planar = new float[channels * sampleCount];
        for (int ch = 0; ch < channels; ch++)
            for (int s = 0; s < sampleCount; s++)
                planar[ch * sampleCount + s] = interleaved[s * channels + ch];

        var handle = GCHandle.Alloc(planar, GCHandleType.Pinned);
        try
        {
            var frame = new NdiInterop.NDIlib_audio_frame_v2_t
            {
                sample_rate = sampleRate,
                no_channels = channels,
                no_samples = sampleCount,
                timecode = NdiInterop.NDIlib_send_timecode_synthesize,
                p_data = handle.AddrOfPinnedObject(),
                channel_stride_in_bytes = sampleCount * sizeof(float)
            };
            NdiInterop.NDIlib_send_send_audio_v2(_sender, ref frame);
        }
        finally
        {
            handle.Free();
        }
    }

    private void EnsureStagingTexture(int width, int height)
    {
        if (_stagingTexture != null)
        {
            var desc = _stagingTexture.Description;
            if (desc.Width == width && desc.Height == height) return;
            _stagingTexture.Dispose();
        }

        _stagingTexture = _device!.CreateTexture2D(new Texture2DDescription
        {
            Width = width,
            Height = height,
            MipLevels = 1,
            ArraySize = 1,
            Format = Format.B8G8R8A8_UNorm,
            SampleDescription = new SampleDescription(1, 0),
            Usage = ResourceUsage.Staging,
            CPUAccessFlags = CpuAccessFlags.Read
        });
    }

    public void Stop()
    {
        if (_sender != IntPtr.Zero)
        {
            NdiInterop.NDIlib_send_destroy(_sender);
            _sender = IntPtr.Zero;
        }
        _stagingTexture?.Dispose();
        _stagingTexture = null;
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        Stop();
        if (_initialized) NdiInterop.NDIlib_destroy();
    }
}
```

**Step 3: Verify it builds**

```bash
dotnet build
```

**Step 4: Commit**

```bash
git add indigo-windows/IndigoWindows/NdiInterop.cs indigo-windows/IndigoWindows/NdiOutput.cs
git commit -m "feat(windows): NDI output with video and audio frame sending"
```

---

### Task 7: Audio Capture (WASAPI Loopback)

**Files:**
- Create: `indigo-windows/IndigoWindows/AudioCapture.cs`

**Step 1: Implement WASAPI loopback capture using NAudio**

```csharp
using System;
using NAudio.CoreAudioApi;
using NAudio.Wave;

namespace IndigoWindows;

public class AudioCapture : IDisposable
{
    public delegate void AudioHandler(float[] buffer, int sampleRate, int channels, int sampleCount);
    public event AudioHandler? OnAudioData;

    private WasapiLoopbackCapture? _capture;
    private bool _disposed;

    public void Start()
    {
        _capture = new WasapiLoopbackCapture();
        _capture.DataAvailable += (_, e) =>
        {
            if (e.BytesRecorded == 0) return;

            var format = _capture.WaveFormat;
            int bytesPerSample = format.BitsPerSample / 8;
            int sampleCount = e.BytesRecorded / (bytesPerSample * format.Channels);

            // Convert byte buffer to float array
            var floats = new float[sampleCount * format.Channels];
            Buffer.BlockCopy(e.Buffer, 0, floats, 0, e.BytesRecorded);

            OnAudioData?.Invoke(floats, format.SampleRate, format.Channels, sampleCount);
        };
        _capture.StartRecording();
    }

    public void Stop()
    {
        _capture?.StopRecording();
        _capture?.Dispose();
        _capture = null;
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        Stop();
    }
}
```

> **Note:** `WasapiLoopbackCapture` captures all system audio by default. For process-specific audio, Windows provides `AudioClient.SetClientProperties` with process loopback (Windows 10 2004+). During implementation, investigate using `WASAPI process loopback` to isolate WebView2 audio only. If not feasible for v1, document as a known limitation.

**Step 2: Verify it builds**

```bash
dotnet build
```

**Step 3: Commit**

```bash
git add indigo-windows/IndigoWindows/AudioCapture.cs
git commit -m "feat(windows): WASAPI loopback audio capture"
```

---

### Task 8: Output Manager (Orchestration)

**Files:**
- Create: `indigo-windows/IndigoWindows/OutputManager.cs`
- Modify: `indigo-windows/IndigoWindows/MainWindow.xaml.cs`

**Step 1: Implement OutputManager**

```csharp
using System;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows.Interop;
using Vortice.Direct3D11;

namespace IndigoWindows;

public class OutputManager : INotifyPropertyChanged, IDisposable
{
    private readonly FrameCapture _frameCapture;
    private readonly SpoutOutput _spoutOutput;
    private readonly NdiOutput _ndiOutput;
    private readonly AudioCapture _audioCapture;
    private bool _isCapturing;
    private string? _error;
    private bool _disposed;

    public bool IsCapturing { get => _isCapturing; private set { _isCapturing = value; OnPropertyChanged(); } }
    public string? Error { get => _error; private set { _error = value; OnPropertyChanged(); } }

    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? name = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    public OutputManager()
    {
        _frameCapture = new FrameCapture();
        _spoutOutput = new SpoutOutput();
        _ndiOutput = new NdiOutput();
        _audioCapture = new AudioCapture();
    }

    public void StartCapture(IntPtr hwnd, AppSettings settings)
    {
        try
        {
            Error = null;

            if (settings.SpoutEnabled)
                _spoutOutput.Start("Indigo", settings.Width, settings.Height);

            if (settings.NdiEnabled)
                _ndiOutput.Start("Indigo", _frameCapture.Device, _frameCapture.Context);

            if (settings.AudioEnabled && settings.NdiEnabled)
            {
                _audioCapture.OnAudioData += OnAudioData;
                _audioCapture.Start();
            }

            _frameCapture.OnFrame += OnVideoFrame;
            _frameCapture.StartCapture(hwnd, settings.Width, settings.Height);

            IsCapturing = true;
        }
        catch (Exception ex)
        {
            Error = ex.Message;
            StopCapture();
        }
    }

    public void StopCapture()
    {
        _frameCapture.OnFrame -= OnVideoFrame;
        _audioCapture.OnAudioData -= OnAudioData;

        _frameCapture.StopCapture();
        _audioCapture.Stop();
        _spoutOutput.Stop();
        _ndiOutput.Stop();

        IsCapturing = false;
    }

    private void OnVideoFrame(ID3D11Texture2D texture, int width, int height)
    {
        if (_spoutOutput.IsRunning)
            _spoutOutput.SendFrame(texture);

        if (_ndiOutput.IsRunning)
            _ndiOutput.SendVideoFrame(texture, width, height);
    }

    private void OnAudioData(float[] buffer, int sampleRate, int channels, int sampleCount)
    {
        if (_ndiOutput.IsRunning)
            _ndiOutput.SendAudioFrame(buffer, sampleRate, channels, sampleCount);
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        StopCapture();
        _frameCapture.Dispose();
        _spoutOutput.Dispose();
        _ndiOutput.Dispose();
        _audioCapture.Dispose();
    }
}
```

**Step 2: Wire OutputManager into MainWindow**

Update `MainWindow.xaml.cs` — replace the placeholder `StartStop_Click`:

```csharp
// Add field:
private readonly OutputManager _outputManager = new();

// In constructor, after InitializeComponent():
_outputManager.PropertyChanged += (_, e) =>
{
    if (e.PropertyName == nameof(OutputManager.Error))
        Dispatcher.Invoke(() => StatusText.Text = _outputManager.Error ?? "");
};

// Replace StartStop_Click:
private void StartStop_Click(object sender, RoutedEventArgs e)
{
    if (_outputManager.IsCapturing)
    {
        _outputManager.StopCapture();
        StartStopBtn.Content = "Start";
        StartStopBtn.Background = new System.Windows.Media.SolidColorBrush(
            System.Windows.Media.Color.FromRgb(0x2E, 0xA0, 0x43));
        SetControlsEnabled(true);
    }
    else
    {
        var hwnd = new WindowInteropHelper(this).Handle;
        _outputManager.StartCapture(hwnd, _settings);
        StartStopBtn.Content = "Stop";
        StartStopBtn.Background = System.Windows.Media.Brushes.Crimson;
        SetControlsEnabled(false);
    }
}

private void SetControlsEnabled(bool enabled)
{
    WidthBox.IsEnabled = enabled;
    HeightBox.IsEnabled = enabled;
    FpsPicker.IsEnabled = enabled;
}

// In Window closing event, dispose:
protected override void OnClosed(EventArgs e)
{
    _outputManager.Dispose();
    base.OnClosed(e);
}
```

**Step 3: Verify it builds**

```bash
dotnet build
```

**Step 4: Commit**

```bash
git add indigo-windows/IndigoWindows/OutputManager.cs indigo-windows/IndigoWindows/MainWindow.xaml.cs
git commit -m "feat(windows): output manager orchestrating capture, Spout, NDI, and audio"
```

---

### Task 9: CSS Injection & WebView2 Navigation Events

**Files:**
- Modify: `indigo-windows/IndigoWindows/MainWindow.xaml.cs`

**Step 1: Add NavigationCompleted handler for CSS injection**

In `InitWebView()`, after `EnsureCoreWebView2Async`:

```csharp
WebView.CoreWebView2.NavigationCompleted += async (_, _) => await InjectCSSAsync();
```

Update `InjectCSS` to be properly async and inject via `AddScriptToExecuteOnDocumentCreatedAsync`:

```csharp
private async Task InjectCSSAsync()
{
    if (WebView.CoreWebView2 == null || string.IsNullOrWhiteSpace(_settings.CustomCSS)) return;
    var escaped = _settings.CustomCSS.Replace("`", "\\`").Replace("\\", "\\\\");
    var script = $@"(function(){{ var s=document.createElement('style'); s.textContent=`{escaped}`; document.head.appendChild(s); }})();";
    await WebView.CoreWebView2.ExecuteScriptAsync(script);
}
```

**Step 2: Verify it builds and CSS gets injected**

```bash
dotnet build
dotnet run
```
Expected: Load a page, custom CSS (transparent background, hidden overflow) applies.

**Step 3: Commit**

```bash
git add indigo-windows/IndigoWindows/MainWindow.xaml.cs
git commit -m "feat(windows): CSS injection on navigation complete"
```

---

### Task 10: Build Script & Packaging

**Files:**
- Create: `indigo-windows/build.ps1`

**Step 1: Create PowerShell build script**

```powershell
# build.ps1 — Build and package Indigo for Windows
$ErrorActionPreference = "Stop"

$publishDir = "publish"
$appName = "Indigo"

Write-Host "Building $appName..." -ForegroundColor Cyan
dotnet publish IndigoWindows/IndigoWindows.csproj -c Release -r win-x64 --self-contained -o $publishDir

# Copy native dependencies
Write-Host "Copying native libraries..." -ForegroundColor Cyan
if (Test-Path "libs/SpoutDX") {
    Copy-Item "libs/SpoutDX/*.dll" $publishDir -Force
}
if (Test-Path "libs/NDI") {
    Copy-Item "libs/NDI/*.dll" $publishDir -Force
}

Write-Host "Build complete: $publishDir/" -ForegroundColor Green
Write-Host "Run: $publishDir/$appName.exe" -ForegroundColor Yellow
```

**Step 2: Verify build**

```bash
cd indigo-windows
pwsh build.ps1
```

**Step 3: Commit**

```bash
git add indigo-windows/build.ps1
git commit -m "feat(windows): build and packaging script"
```

---

### Task 11: Integration Testing & Polish

**Step 1: Manual test checklist**

- [ ] App launches, WebView2 loads example.com
- [ ] URL bar navigation works (type URL + Enter)
- [ ] Back/Forward/Reload buttons work
- [ ] Settings panel toggles visibility
- [ ] Resolution presets (720p/1080p/4K) update fields
- [ ] Custom CSS applies to loaded page
- [ ] Start captures window and outputs to Spout (verify in Resolume or SpoutReceiver)
- [ ] NDI sender appears in NDI Monitor
- [ ] Audio plays through NDI
- [ ] Stop cleanly releases all resources
- [ ] Settings persist across app restarts
- [ ] Clear Cache clears WebView2 browsing data

**Step 2: Fix any issues found during testing**

**Step 3: Final commit**

```bash
git add -A indigo-windows/
git commit -m "fix(windows): integration testing fixes and polish"
```

---

## Dependency Setup Notes

### NDI SDK
- Download from https://ndi.video/tools/ (NDI SDK for Windows)
- Copy `Processing.NDI.Lib.x64.dll` to `indigo-windows/libs/NDI/`
- Or install NDI Tools which puts the DLL in `C:\Program Files\NDI\NDI 5 Runtime\`

### Spout SDK
- Download from https://github.com/leadedge/Spout2/releases
- Copy `SpoutLibrary.dll` (or `SpoutDX.dll`) to `indigo-windows/libs/SpoutDX/`
- Alternatively, use the **Spout.NET** NuGet wrapper if available

### WebView2 Runtime
- Pre-installed on Windows 11
- For Windows 10: bundled via Evergreen bootstrapper or fixed-version distribution
