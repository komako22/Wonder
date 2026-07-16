using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text.Json;
using GlassTranslate.Windows.Models;
using Microsoft.Win32;

namespace GlassTranslate.Windows.Services;

public sealed class SettingsStore
{
    private const string StartupName = "Wonder";
    private readonly string _folder = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Wonder");

    private string SettingsPath => Path.Combine(_folder, "settings.json");
    public string FreeServiceEmail { get; set; } = string.Empty;
    public TargetLanguage TargetLanguage { get; set; } = TargetLanguage.Automatic;
    public bool IsPaused { get; set; }
    public bool LaunchAtLogin { get; set; }
    public SelectionMethod SelectionMethod { get; set; } = SelectionMethod.Automatic;
    public double SelectionDelay { get; set; } = 0.18;
    public double BubbleScale { get; set; } = 1.0;
    public BubblePosition BubblePosition { get; set; } = BubblePosition.Below;
    public GlassTheme GlassTheme { get; set; } = GlassTheme.Aurora;
    public double TranslationFontSize { get; set; } = 16;
    public bool ShowSourceText { get; set; } = true;

    public void Load()
    {
        Directory.CreateDirectory(_folder);
        if (File.Exists(SettingsPath))
        {
            try
            {
                var data = JsonSerializer.Deserialize<PersistedSettings>(File.ReadAllText(SettingsPath));
                if (data is not null)
                {
                    FreeServiceEmail = data.FreeServiceEmail ?? string.Empty;
                    TargetLanguage = data.TargetLanguage;
                    IsPaused = data.IsPaused;
                    SelectionMethod = data.SelectionMethod;
                    SelectionDelay = data.SelectionDelay;
                    BubbleScale = data.BubbleScale;
                    BubblePosition = data.BubblePosition;
                    GlassTheme = data.GlassTheme;
                    TranslationFontSize = data.TranslationFontSize;
                    ShowSourceText = data.ShowSourceText;
                }
            }
            catch { /* Keep safe defaults when local settings are damaged. */ }
        }
        LaunchAtLogin = ReadLaunchAtLogin();
    }

    public void Save()
    {
        Directory.CreateDirectory(_folder);
        var json = JsonSerializer.Serialize(
            new PersistedSettings(FreeServiceEmail.Trim(), TargetLanguage, IsPaused,
                SelectionMethod, SelectionDelay, BubbleScale, BubblePosition, GlassTheme, TranslationFontSize, ShowSourceText),
            new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(SettingsPath, json);
        WriteLaunchAtLogin(LaunchAtLogin);
    }

    private static bool ReadLaunchAtLogin()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");
        return key?.GetValue(StartupName) is string;
    }

    private static void WriteLaunchAtLogin(bool enabled)
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", writable: true);
        if (key is null) return;
        if (!enabled)
        {
            key.DeleteValue(StartupName, throwOnMissingValue: false);
            return;
        }

        var processPath = Environment.ProcessPath ?? Process.GetCurrentProcess().MainModule?.FileName ?? string.Empty;
        var entryName = Assembly.GetEntryAssembly()?.GetName().Name ?? "Wonder";
        var entryPath = Path.Combine(AppContext.BaseDirectory, $"{entryName}.dll");
        var command = Path.GetFileNameWithoutExtension(processPath).Equals("dotnet", StringComparison.OrdinalIgnoreCase)
            ? $"\"{processPath}\" \"{entryPath}\""
            : $"\"{processPath}\"";
        key.SetValue(StartupName, command);
    }

    private sealed record PersistedSettings(
        string? FreeServiceEmail = "",
        TargetLanguage TargetLanguage = TargetLanguage.Automatic,
        bool IsPaused = false,
        SelectionMethod SelectionMethod = SelectionMethod.Automatic,
        double SelectionDelay = 0.18,
        double BubbleScale = 1.0,
        BubblePosition BubblePosition = BubblePosition.Below,
        GlassTheme GlassTheme = GlassTheme.Aurora,
        double TranslationFontSize = 16,
        bool ShowSourceText = true);
}
