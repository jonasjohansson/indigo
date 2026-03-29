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
            try
            {
                _initialized = NdiInterop.NDIlib_initialize();
            }
            catch (DllNotFoundException)
            {
                System.Diagnostics.Debug.WriteLine("NDI SDK DLL not found — NDI output disabled.");
                return;
            }
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

    public void SendVideoFrame(ID3D11Texture2D sourceTexture, int width, int height, int fps)
    {
        if (_sender == IntPtr.Zero || _device == null || _context == null) return;

        EnsureStagingTexture(width, height);

        _context.CopyResource(_stagingTexture!, sourceTexture);
        var mapped = _context.Map(_stagingTexture!, 0, MapMode.Read);

        try
        {
            var frame = new NdiInterop.NDIlib_video_frame_v2_t
            {
                xres = width,
                yres = height,
                FourCC = NdiInterop.NDIlib_FourCC_video_type_BGRA,
                frame_rate_N = fps * 1000,
                frame_rate_D = 1000,
                picture_aspect_ratio = (float)width / height,
                frame_format_type = 1, // progressive
                timecode = NdiInterop.NDIlib_send_timecode_synthesize,
                p_data = mapped.DataPointer,
                line_stride_in_bytes = (int)mapped.RowPitch
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

        // Deinterleave: [L0,R0,L1,R1,...] -> [L0,L1,...,R0,R1,...]
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
            if (desc.Width == (uint)width && desc.Height == (uint)height) return;
            _stagingTexture.Dispose();
        }

        _stagingTexture = _device!.CreateTexture2D(new Texture2DDescription
        {
            Width = (uint)width,
            Height = (uint)height,
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
