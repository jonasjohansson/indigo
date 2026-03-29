using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;

namespace IndigoWindows;

public partial class App : Application
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool AddDllDirectory(string newDirectory);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetDefaultDllDirectories(uint directoryFlags);

    private const uint LOAD_LIBRARY_SEARCH_DEFAULT_DIRS = 0x00001000;

    protected override void OnStartup(StartupEventArgs e)
    {
        // Enable searching additional DLL directories
        SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);

        // Add NDI runtime directories to DLL search path
        string[] ndiPaths = [
            @"C:\Program Files\NDI\NDI 6 Runtime\v6",
            @"C:\Program Files\NDI\NDI 5 Runtime",
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "libs", "NDI"),
        ];

        foreach (var path in ndiPaths)
        {
            if (Directory.Exists(path))
                AddDllDirectory(path);
        }

        base.OnStartup(e);
    }
}
