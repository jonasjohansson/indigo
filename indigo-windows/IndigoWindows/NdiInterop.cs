using System;
using System.Runtime.InteropServices;

namespace IndigoWindows;

public static class NdiInterop
{
    private const string NdiLib = "Processing.NDI.Lib.x64";

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
        public int FourCC;
        public int frame_rate_N, frame_rate_D;
        public float picture_aspect_ratio;
        public int frame_format_type;
        public long timecode;
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

    public const int NDIlib_FourCC_video_type_BGRA = 0x41524742;
    public const long NDIlib_send_timecode_synthesize = long.MaxValue;
}
