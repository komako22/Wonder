using System.Windows;

namespace GlassTranslate.Windows.Models;

public sealed record SelectionSnapshot(string Text, Rect ScreenRect)
{
    public string Signature => $"{Text}|{(int)ScreenRect.X}|{(int)ScreenRect.Y}|{(int)ScreenRect.Width}|{(int)ScreenRect.Height}";
}

public enum SelectionMethod { Automatic, AccessibilityOnly, ClipboardOnly }
public enum BubblePosition { Below, Above, Pointer }
public enum GlassTheme { System, Frost, Midnight, Aurora }

public enum TargetLanguage
{
    Automatic,
    SimplifiedChinese,
    English,
    Japanese,
    Korean,
    French,
    German,
    Spanish
}

public static class TargetLanguageExtensions
{
    public static string DisplayName(this TargetLanguage value) => value switch
    {
        TargetLanguage.Automatic => "自动（中英互译）",
        TargetLanguage.SimplifiedChinese => "简体中文",
        TargetLanguage.English => "English",
        TargetLanguage.Japanese => "日本語",
        TargetLanguage.Korean => "한국어",
        TargetLanguage.French => "Français",
        TargetLanguage.German => "Deutsch",
        TargetLanguage.Spanish => "Español",
        _ => value.ToString()
    };
}
