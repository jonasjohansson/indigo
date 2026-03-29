using System;
using System.Runtime.InteropServices;
using Vortice.Direct3D11;

namespace IndigoWindows;

/// <summary>
/// Spout output using the prebuilt SpoutDX.dll (C++ class with mangled exports).
/// On x64 Windows, C++ member functions use the Microsoft x64 calling convention
/// where 'this' is passed as the first parameter (rcx), so we can P/Invoke them
/// by passing the object pointer as the first argument.
///
/// The spoutDX object is allocated via CoTaskMemAlloc + constructor call.
/// </summary>
public class SpoutOutput : IDisposable
{
    private IntPtr _spout;
    private bool _disposed;

    public bool IsRunning => _spout != IntPtr.Zero;

    public void Start(string name, int width, int height, ID3D11Device device)
    {
        try
        {
            // Allocate memory for spoutDX object (generous size for the class instance)
            _spout = Marshal.AllocHGlobal(8192);
            SpoutDXNative.Constructor(_spout);

            // Initialize DirectX with our existing device
            SpoutDXNative.OpenDirectX11(_spout, device.NativePointer);

            // Set sender name and start sending
            SpoutDXNative.SetSenderName(_spout, name);
        }
        catch (DllNotFoundException)
        {
            System.Diagnostics.Debug.WriteLine("SpoutDX.dll not found — Spout output disabled.");
            if (_spout != IntPtr.Zero)
            {
                Marshal.FreeHGlobal(_spout);
                _spout = IntPtr.Zero;
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Spout initialization failed: {ex.Message}");
            if (_spout != IntPtr.Zero)
            {
                Marshal.FreeHGlobal(_spout);
                _spout = IntPtr.Zero;
            }
        }
    }

    public void SendFrame(ID3D11Texture2D texture)
    {
        if (_spout == IntPtr.Zero) return;
        try
        {
            SpoutDXNative.SendTexture(_spout, texture.NativePointer);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Spout SendTexture failed: {ex.Message}");
        }
    }

    public void Stop()
    {
        if (_spout != IntPtr.Zero)
        {
            try
            {
                SpoutDXNative.ReleaseSender(_spout);
                SpoutDXNative.CloseDirectX11(_spout);
                SpoutDXNative.Destructor(_spout);
            }
            catch { }
            Marshal.FreeHGlobal(_spout);
            _spout = IntPtr.Zero;
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        Stop();
    }
}

/// <summary>
/// P/Invoke bindings for SpoutDX.dll using C++ mangled export names.
/// These target the spoutDX class methods from the prebuilt x64 DLL.
/// 'this' pointer is passed as the first IntPtr parameter.
/// </summary>
internal static class SpoutDXNative
{
    private const string Lib = "SpoutDX";

    // spoutDX::spoutDX() — constructor
    [DllImport(Lib, EntryPoint = "??0spoutDX@@QEAA@XZ", CallingConvention = CallingConvention.ThisCall)]
    public static extern void Constructor(IntPtr thisPtr);

    // spoutDX::~spoutDX() — destructor
    [DllImport(Lib, EntryPoint = "??1spoutDX@@QEAA@XZ", CallingConvention = CallingConvention.ThisCall)]
    public static extern void Destructor(IntPtr thisPtr);

    // bool spoutDX::OpenDirectX11(ID3D11Device*)
    [DllImport(Lib, EntryPoint = "?OpenDirectX11@spoutDX@@QEAA_NPEAUID3D11Device@@@Z", CallingConvention = CallingConvention.ThisCall)]
    [return: MarshalAs(UnmanagedType.U1)]
    public static extern bool OpenDirectX11(IntPtr thisPtr, IntPtr pDevice);

    // void spoutDX::CloseDirectX11()
    [DllImport(Lib, EntryPoint = "?CloseDirectX11@spoutDX@@QEAAXXZ", CallingConvention = CallingConvention.ThisCall)]
    public static extern void CloseDirectX11(IntPtr thisPtr);

    // bool spoutDX::SetSenderName(const char*)
    [DllImport(Lib, EntryPoint = "?SetSenderName@spoutDX@@QEAA_NPEBD@Z", CallingConvention = CallingConvention.ThisCall)]
    [return: MarshalAs(UnmanagedType.U1)]
    public static extern bool SetSenderName(IntPtr thisPtr, [MarshalAs(UnmanagedType.LPStr)] string name);

    // bool spoutDX::SendTexture(ID3D11Texture2D*)
    [DllImport(Lib, EntryPoint = "?SendTexture@spoutDX@@QEAA_NPEAUID3D11Texture2D@@@Z", CallingConvention = CallingConvention.ThisCall)]
    [return: MarshalAs(UnmanagedType.U1)]
    public static extern bool SendTexture(IntPtr thisPtr, IntPtr pTexture);

    // void spoutDX::ReleaseSender()
    [DllImport(Lib, EntryPoint = "?ReleaseSender@spoutDX@@QEAAXXZ", CallingConvention = CallingConvention.ThisCall)]
    public static extern void ReleaseSender(IntPtr thisPtr);
}
