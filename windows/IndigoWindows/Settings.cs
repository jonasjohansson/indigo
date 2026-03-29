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
