using System;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Microsoft.Web.WebView2.Core;

namespace IndigoWindows;

public partial class MainWindow : Window
{
    private AppSettings _settings = null!;
    private readonly OutputManager _outputManager = new();

    public MainWindow()
    {
        InitializeComponent();

        _settings = AppSettings.Load();
        DataContext = _settings;

        _settings.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName is nameof(AppSettings.Width) or nameof(AppSettings.Height))
                Dispatcher.Invoke(UpdateResolutionLabel);
        };

        FpsPicker.SelectedIndex = _settings.Fps == 30 ? 0 : 1;
        UpdateResolutionLabel();

        _outputManager.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(OutputManager.Error))
                Dispatcher.Invoke(() => StatusText.Text = _outputManager.Error ?? "");
        };

        Loaded += MainWindow_Loaded;
        SizeChanged += OnWindowSizeChanged;
        SourceInitialized += (_, _) =>
        {
            var hwnd = new System.Windows.Interop.WindowInteropHelper(this).Handle;
            var source = System.Windows.Interop.HwndSource.FromHwnd(hwnd);
            source?.AddHook(WndProc);
        };
    }

    // WM_SIZING: enforce aspect ratio while capturing
    private const int WM_SIZING = 0x0214;
    private const int WMSZ_LEFT = 1, WMSZ_RIGHT = 2, WMSZ_TOP = 3, WMSZ_BOTTOM = 6;

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WM_SIZING && _outputManager.IsCapturing)
        {
            var rect = Marshal.PtrToStructure<RECT>(lParam);
            double targetAspect = (double)_settings.Width / _settings.Height;
            int edge = wParam.ToInt32();

            int w = rect.Right - rect.Left;
            int h = rect.Bottom - rect.Top;

            // Adjust based on which edge is being dragged
            if (edge is WMSZ_RIGHT or WMSZ_LEFT or (WMSZ_RIGHT | WMSZ_TOP) or (WMSZ_LEFT | WMSZ_TOP)
                or (WMSZ_RIGHT | WMSZ_BOTTOM) or (WMSZ_LEFT | WMSZ_BOTTOM))
            {
                // Width changed — adjust height
                int newH = (int)(w / targetAspect);
                if (edge is WMSZ_TOP or (WMSZ_RIGHT | WMSZ_TOP) or (WMSZ_LEFT | WMSZ_TOP))
                    rect.Top = rect.Bottom - newH;
                else
                    rect.Bottom = rect.Top + newH;
            }
            else
            {
                // Height changed — adjust width
                int newW = (int)(h * targetAspect);
                if (edge is WMSZ_LEFT)
                    rect.Left = rect.Right - newW;
                else
                    rect.Right = rect.Left + newW;
            }

            Marshal.StructureToPtr(rect, lParam, false);
            handled = true;
        }
        return IntPtr.Zero;
    }

    private void OnWindowSizeChanged(object sender, SizeChangedEventArgs e)
    {
        if (!_outputManager.IsCapturing) return;

        var (cx, cy, cw, ch) = GetWebViewBoundsInPixels();
        _outputManager.UpdateCropRect(cx, cy, cw, ch);
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        await WebView.EnsureCoreWebView2Async();
        WebView.CoreWebView2.NavigationCompleted += async (_, _) => await InjectCSSAsync();
        NavigateToUrl(_settings.Url);
    }

    // --- Navigation ---

    private void BackButton_Click(object sender, RoutedEventArgs e)
    {
        if (WebView.CoreWebView2?.CanGoBack == true)
            WebView.CoreWebView2.GoBack();
    }

    private void ForwardButton_Click(object sender, RoutedEventArgs e)
    {
        if (WebView.CoreWebView2?.CanGoForward == true)
            WebView.CoreWebView2.GoForward();
    }

    private void ReloadButton_Click(object sender, RoutedEventArgs e)
    {
        WebView.CoreWebView2?.Reload();
    }

    private void UrlBar_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
        {
            NavigateToUrl(UrlBar.Text);
            WebView.Focus();
        }
    }

    private void NavigateToUrl(string url)
    {
        if (string.IsNullOrWhiteSpace(url)) return;

        url = url.Trim();
        if (!url.Contains("://"))
            url = "https://" + url;

        _settings.Url = url;
        UrlBar.Text = url;

        if (WebView.CoreWebView2 != null)
            WebView.CoreWebView2.Navigate(url);
    }

    private async Task InjectCSSAsync()
    {
        if (WebView.CoreWebView2 == null || string.IsNullOrWhiteSpace(_settings.CustomCSS)) return;
        var escaped = _settings.CustomCSS.Replace("\\", "\\\\").Replace("`", "\\`");
        var script = $@"(function(){{ var s=document.createElement('style'); s.textContent=`{escaped}`; document.head.appendChild(s); }})();";
        await WebView.CoreWebView2.ExecuteScriptAsync(script);
    }

    // --- Settings Panel ---

    private void SettingsToggle_Click(object sender, RoutedEventArgs e)
    {
        SettingsPanel.Visibility = SettingsToggle.IsChecked == true
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    // --- Presets ---

    private void Preset720_Click(object sender, RoutedEventArgs e)
    {
        _settings.Width = 1280;
        _settings.Height = 720;
    }

    private void Preset1080_Click(object sender, RoutedEventArgs e)
    {
        _settings.Width = 1920;
        _settings.Height = 1080;
    }

    private void Preset4K_Click(object sender, RoutedEventArgs e)
    {
        _settings.Width = 3840;
        _settings.Height = 2160;
    }

    private void UpdateResolutionLabel()
    {
        ResolutionLabel.Text = $"{_settings.Width} x {_settings.Height}";
    }

    // --- Clear Cache ---

    private async void ClearCache_Click(object sender, RoutedEventArgs e)
    {
        if (WebView.CoreWebView2 == null) return;
        await WebView.CoreWebView2.Profile.ClearBrowsingDataAsync();
        WebView.CoreWebView2.Reload();
    }

    // --- FPS Picker ---

    private void FpsPicker_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (FpsPicker.SelectedItem is ComboBoxItem item && item.Tag is string tag)
        {
            _settings.Fps = int.Parse(tag);
        }
    }

    // --- Start / Stop ---

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    [DllImport("user32.dll")]
    private static extern bool ClientToScreen(IntPtr hWnd, ref POINT point);

    [DllImport("dwmapi.dll")]
    private static extern int DwmGetWindowAttribute(IntPtr hwnd, int dwAttribute, out RECT pvAttribute, int cbAttribute);

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT { public int X, Y; }

    private const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;

    /// <summary>
    /// Get the WebView2 bounds within the captured window image in physical pixels.
    /// Windows.Graphics.Capture captures the visible frame (excluding shadow),
    /// so we use DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS) to get the
    /// actual captured region, then offset from there.
    /// </summary>
    private (int x, int y, int w, int h) GetWebViewBoundsInPixels()
    {
        var hwnd = new System.Windows.Interop.WindowInteropHelper(this).Handle;

        // Get the extended frame bounds — this is what Graphics.Capture actually captures
        // (the visible window, excluding the invisible DWM shadow)
        DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS,
            out var frameRect, Marshal.SizeOf<RECT>());

        // Get the client area origin in screen coords
        var clientOrigin = new POINT { X = 0, Y = 0 };
        ClientToScreen(hwnd, ref clientOrigin);

        // Offset from the captured frame origin to the client area
        int ncOffsetX = clientOrigin.X - frameRect.Left;
        int ncOffsetY = clientOrigin.Y - frameRect.Top;

        // Get WebView position relative to the WPF window client area
        var source = PresentationSource.FromVisual(this);
        double dpiX = source?.CompositionTarget?.TransformToDevice.M11 ?? 1.0;
        double dpiY = source?.CompositionTarget?.TransformToDevice.M22 ?? 1.0;

        var webViewPos = WebView.TransformToAncestor(this).Transform(new Point(0, 0));

        // Final position = frame-to-client offset + WebView position within client area
        int x = ncOffsetX + (int)(webViewPos.X * dpiX);
        int y = ncOffsetY + (int)(webViewPos.Y * dpiY);
        int w = (int)(WebView.ActualWidth * dpiX);
        int h = (int)(WebView.ActualHeight * dpiY);

        return (x, y, w, h);
    }

    private void StartStop_Click(object sender, RoutedEventArgs e)
    {
        if (_outputManager.IsCapturing)
        {
            _outputManager.StopCapture();
            StartStopButton.Content = "Start";
            StartStopButton.Background = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#2EA043"));
            StatusText.Text = "Idle";
            SetControlsEnabled(true);
        }
        else
        {
            // Calculate the WebView2 crop rect within the window (in physical pixels)
            var (cx, cy, cw, ch) = GetWebViewBoundsInPixels();

            var hwnd = new System.Windows.Interop.WindowInteropHelper(this).Handle;
            _outputManager.StartCapture(hwnd, _settings, cx, cy, cw, ch);

            if (_outputManager.IsCapturing)
            {
                StartStopButton.Content = "Stop";
                StartStopButton.Background = new SolidColorBrush(Colors.Crimson);
                StatusText.Text = $"Capturing {_settings.Width}x{_settings.Height}...";
                SetControlsEnabled(false);
            }
            else
            {
                StatusText.Text = _outputManager.Error ?? "Failed to start capture";
            }
        }
    }

    private void SetControlsEnabled(bool enabled)
    {
        WidthBox.IsEnabled = enabled;
        HeightBox.IsEnabled = enabled;
        FpsPicker.IsEnabled = enabled;
    }

    protected override void OnClosed(EventArgs e)
    {
        _outputManager.Dispose();
        base.OnClosed(e);
    }
}
