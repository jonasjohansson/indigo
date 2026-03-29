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
    private static extern int CreateDirect3D11DeviceFromDXGIDevice(
        IntPtr dxgiDevice, out IntPtr graphicsDevice);

    [ComImport]
    [Guid("3628E81B-3CAC-4C60-B7F4-23CE0E0C3356")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IGraphicsCaptureItemInterop
    {
        IntPtr CreateForWindow(
            [In] IntPtr window,
            [In] ref Guid iid);
    }

    [ComImport]
    [Guid("A9B3D012-3DF2-4EE3-B8D1-8695F457D3C1")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IDirect3DDxgiInterfaceAccess
    {
        IntPtr GetInterface([In] ref Guid iid);
    }

    // HSTRING helpers
    [DllImport("combase.dll", PreserveSig = false)]
    private static extern void WindowsCreateString(
        [MarshalAs(UnmanagedType.LPWStr)] string sourceString,
        int length,
        out IntPtr hstring);

    [DllImport("combase.dll", PreserveSig = false)]
    private static extern void WindowsDeleteString(IntPtr hstring);

    [DllImport("combase.dll", PreserveSig = false)]
    private static extern void RoGetActivationFactory(
        IntPtr activatableClassId,
        ref Guid iid,
        out IntPtr factory);

    public static GraphicsCaptureItem? CreateItemForWindow(IntPtr hwnd)
    {
        // Get activation factory for GraphicsCaptureItem
        var className = "Windows.Graphics.Capture.GraphicsCaptureItem";
        WindowsCreateString(className, className.Length, out var hstring);
        try
        {
            var iid = new Guid("00000035-0000-0000-C000-000000000046"); // IActivationFactory
            RoGetActivationFactory(hstring, ref iid, out var factoryPtr);

            var interop = (IGraphicsCaptureItemInterop)Marshal.GetObjectForIUnknown(factoryPtr);
            Marshal.Release(factoryPtr);

            // IGraphicsCaptureItem IID
            var itemIid = new Guid("79C3F95B-31F7-4EC2-A464-632EF5D30760");
            var ptr = interop.CreateForWindow(hwnd, ref itemIid);
            if (ptr == IntPtr.Zero) return null;

            var item = MarshalInterface<GraphicsCaptureItem>.FromAbi(ptr);
            Marshal.Release(ptr);
            return item;
        }
        finally
        {
            WindowsDeleteString(hstring);
        }
    }

    public static IDirect3DDevice? CreateDirect3DDeviceFromD3D11(ID3D11Device d3d11Device)
    {
        using var dxgiDevice = d3d11Device.QueryInterface<IDXGIDevice>();
        int hr = CreateDirect3D11DeviceFromDXGIDevice(dxgiDevice.NativePointer, out var pUnk);
        if (hr != 0) return null;

        var device = MarshalInterface<IDirect3DDevice>.FromAbi(pUnk);
        Marshal.Release(pUnk);
        return device;
    }

    public static ID3D11Texture2D? GetTextureFromSurface(IDirect3DSurface surface, ID3D11Device device)
    {
        var access = surface.As<IDirect3DDxgiInterfaceAccess>();
        var iid = typeof(ID3D11Texture2D).GUID;
        var ptr = access.GetInterface(ref iid);
        if (ptr == IntPtr.Zero) return null;
        return new ID3D11Texture2D(ptr);
    }
}
