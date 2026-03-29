using System;
using Vortice.Direct3D;
using Vortice.Direct3D11;
using Vortice.DXGI;
using Vortice.Mathematics;
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
    private Direct3D11CaptureFramePool? _framePool;
    private GraphicsCaptureSession? _session;
    private IDirect3DDevice? _winrtDevice;
    private GraphicsCaptureItem? _captureItem;
    private bool _disposed;

    // Source rect to crop from the captured window (in pixels)
    private int _cropX, _cropY, _cropW, _cropH;
    private bool _hasCrop;

    // Track last known capture size to detect when frame pool needs resizing
    private SizeInt32 _lastSize;

    public ID3D11Device Device => _device;
    public ID3D11DeviceContext Context => _context;

    public FrameCapture()
    {
        D3D11.D3D11CreateDevice(
            null,
            DriverType.Hardware,
            DeviceCreationFlags.BgraSupport,
            [FeatureLevel.Level_11_0],
            out _device!,
            out _context!);

        using var mt = _device.QueryInterface<ID3D11Multithread>();
        mt.SetMultithreadProtected(true);
    }

    public void SetSourceRect(int x, int y, int width, int height)
    {
        _cropX = x;
        _cropY = y;
        _cropW = width;
        _cropH = height;
        _hasCrop = true;
    }

    public void StartCapture(IntPtr hwnd)
    {
        _captureItem = CaptureHelper.CreateItemForWindow(hwnd);
        if (_captureItem == null)
            throw new InvalidOperationException("Cannot create capture item for window.");

        _winrtDevice = CaptureHelper.CreateDirect3DDeviceFromD3D11(_device);
        if (_winrtDevice == null)
            throw new InvalidOperationException("Cannot create WinRT Direct3D device.");

        _lastSize = _captureItem.Size;

        _framePool = Direct3D11CaptureFramePool.CreateFreeThreaded(
            _winrtDevice,
            DirectXPixelFormat.B8G8R8A8UIntNormalized,
            2,
            _lastSize);

        _framePool.FrameArrived += OnFrameArrived;

        _session = _framePool.CreateCaptureSession(_captureItem);
        _session.IsCursorCaptureEnabled = false;
        _session.StartCapture();
    }

    private void OnFrameArrived(Direct3D11CaptureFramePool sender, object args)
    {
        using var frame = sender.TryGetNextFrame();
        if (frame == null) return;

        // If the window was resized, recreate the frame pool at the new size
        var newSize = frame.ContentSize;
        if (newSize.Width != _lastSize.Width || newSize.Height != _lastSize.Height)
        {
            _lastSize = newSize;
            _framePool?.Recreate(_winrtDevice!, DirectXPixelFormat.B8G8R8A8UIntNormalized, 2, newSize);
            return; // Skip this frame, next one will be at the new size
        }

        var srcTexture = CaptureHelper.GetTextureFromSurface(frame.Surface, _device);
        if (srcTexture == null) return;

        try
        {
            if (!_hasCrop)
            {
                OnFrame?.Invoke(srcTexture, newSize.Width, newSize.Height);
                return;
            }

            int srcW = newSize.Width;
            int srcH = newSize.Height;

            int cx = Math.Min(_cropX, srcW);
            int cy = Math.Min(_cropY, srcH);
            int cw = Math.Min(_cropW, srcW - cx);
            int ch = Math.Min(_cropH, srcH - cy);

            if (cw <= 0 || ch <= 0) return;

            using var croppedTexture = _device.CreateTexture2D(new Texture2DDescription
            {
                Width = (uint)cw,
                Height = (uint)ch,
                MipLevels = 1,
                ArraySize = 1,
                Format = Format.B8G8R8A8_UNorm,
                SampleDescription = new SampleDescription(1, 0),
                Usage = ResourceUsage.Default,
                BindFlags = BindFlags.ShaderResource,
            });

            _context.CopySubresourceRegion(
                croppedTexture, 0, 0, 0, 0,
                srcTexture, 0,
                new Box(cx, cy, 0, cx + cw, cy + ch, 1));

            OnFrame?.Invoke(croppedTexture, cw, ch);
        }
        finally
        {
            srcTexture.Dispose();
        }
    }

    public void StopCapture()
    {
        _session?.Dispose();
        _session = null;
        _framePool?.Dispose();
        _framePool = null;
        _captureItem = null;
        _hasCrop = false;
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        StopCapture();
        _winrtDevice?.Dispose();
        _context?.Dispose();
        _device?.Dispose();
        GC.SuppressFinalize(this);
    }
}
