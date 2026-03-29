using System;
using NAudio.CoreAudioApi;
using NAudio.Wave;

namespace IndigoWindows;

// TODO: WasapiLoopbackCapture captures ALL system audio, not just the WebView2 process.
// Process-specific audio isolation via WASAPI process loopback (Windows 10 2004+) can be explored later.

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

            // WASAPI loopback delivers IEEE float32 samples
            var floats = new float[sampleCount * format.Channels];
            Buffer.BlockCopy(e.Buffer, 0, floats, 0, sampleCount * format.Channels * sizeof(float));

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
