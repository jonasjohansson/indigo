using System;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using Vortice.Direct3D11;

namespace IndigoWindows;

public class OutputManager : INotifyPropertyChanged, IDisposable
{
    private readonly FrameCapture _frameCapture;
    private readonly SpoutOutput _spoutOutput;
    private readonly NdiOutput _ndiOutput;
    private readonly AudioCapture _audioCapture;
    private TextureScaler? _scaler;
    private bool _isCapturing;
    private string? _error;
    private bool _disposed;
    private int _fps = 60;
    private int _outputWidth;
    private int _outputHeight;

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

    public void StartCapture(IntPtr hwnd, AppSettings settings, int cropX, int cropY, int cropW, int cropH)
    {
        try
        {
            Error = null;
            _outputWidth = settings.Width;
            _outputHeight = settings.Height;

            _scaler = new TextureScaler(_frameCapture.Device, _frameCapture.Context);
            _scaler.EnsureOutputTexture(_outputWidth, _outputHeight);

            if (settings.SpoutEnabled)
                _spoutOutput.Start("Indigo", _outputWidth, _outputHeight, _frameCapture.Device);

            if (settings.NdiEnabled)
                _ndiOutput.Start("Indigo", _frameCapture.Device, _frameCapture.Context);

            if (settings.AudioEnabled && settings.NdiEnabled)
            {
                _audioCapture.OnAudioData += OnAudioData;
                _audioCapture.Start();
            }

            _fps = settings.Fps;

            _frameCapture.SetSourceRect(cropX, cropY, cropW, cropH);
            _frameCapture.OnFrame += OnVideoFrame;
            _frameCapture.StartCapture(hwnd);

            IsCapturing = true;
        }
        catch (Exception ex)
        {
            Error = ex.Message;
            StopCapture();
        }
    }

    public void UpdateCropRect(int x, int y, int w, int h)
    {
        _frameCapture.SetSourceRect(x, y, w, h);
    }

    public void StopCapture()
    {
        _frameCapture.OnFrame -= OnVideoFrame;
        _audioCapture.OnAudioData -= OnAudioData;

        _frameCapture.StopCapture();
        _audioCapture.Stop();
        _spoutOutput.Stop();
        _ndiOutput.Stop();
        _scaler?.Dispose();
        _scaler = null;

        IsCapturing = false;
        Error = null;
    }

    private void OnVideoFrame(ID3D11Texture2D texture, int width, int height)
    {
        // Scale the cropped WebView frame to the configured output resolution
        var outputTexture = texture;
        int outW = width;
        int outH = height;

        if (_scaler != null && (width != _outputWidth || height != _outputHeight))
        {
            outputTexture = _scaler.Scale(texture);
            outW = _outputWidth;
            outH = _outputHeight;
        }

        if (_spoutOutput.IsRunning)
            _spoutOutput.SendFrame(outputTexture);

        if (_ndiOutput.IsRunning)
            _ndiOutput.SendVideoFrame(outputTexture, outW, outH, _fps);
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
