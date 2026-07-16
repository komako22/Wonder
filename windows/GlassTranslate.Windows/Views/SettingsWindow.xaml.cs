using System.Windows;
using System.Windows.Interop;
using System.Windows.Input;
using GlassTranslate.Windows.Interop;
using GlassTranslate.Windows.Models;
using GlassTranslate.Windows.Services;

namespace GlassTranslate.Windows.Views;

public partial class SettingsWindow : Window
{
    private readonly SettingsStore _settings;
    public event Action? SettingsSaved;

    private sealed record LanguageOption(TargetLanguage Value, string Name);
    private sealed record Option<T>(T Value, string Name);

    public SettingsWindow(SettingsStore settings)
    {
        InitializeComponent();
        _settings = settings;
        FreeEmailBox.Text = settings.FreeServiceEmail;
        LanguageBox.ItemsSource = Enum.GetValues<TargetLanguage>()
            .Select(value => new LanguageOption(value, value.DisplayName()))
            .ToArray();
        LanguageBox.SelectedIndex = Array.IndexOf(Enum.GetValues<TargetLanguage>(), settings.TargetLanguage);
        SelectionMethodBox.ItemsSource = new[]
        {
            new Option<SelectionMethod>(SelectionMethod.Automatic, "自动兼容（推荐）"),
            new Option<SelectionMethod>(SelectionMethod.AccessibilityOnly, "仅 UI Automation"),
            new Option<SelectionMethod>(SelectionMethod.ClipboardOnly, "仅安全复制")
        };
        SelectionMethodBox.SelectedIndex = Array.IndexOf(Enum.GetValues<SelectionMethod>(), settings.SelectionMethod);
        BubblePositionBox.ItemsSource = new[]
        {
            new Option<BubblePosition>(BubblePosition.Below, "选区下方"),
            new Option<BubblePosition>(BubblePosition.Above, "选区上方"),
            new Option<BubblePosition>(BubblePosition.Pointer, "鼠标附近")
        };
        BubblePositionBox.SelectedIndex = Array.IndexOf(Enum.GetValues<BubblePosition>(), settings.BubblePosition);
        ThemeBox.ItemsSource = new[]
        {
            new Option<GlassTheme>(GlassTheme.System, "跟随系统"),
            new Option<GlassTheme>(GlassTheme.Frost, "霜白"),
            new Option<GlassTheme>(GlassTheme.Midnight, "深海"),
            new Option<GlassTheme>(GlassTheme.Aurora, "极光")
        };
        ThemeBox.SelectedIndex = Array.IndexOf(Enum.GetValues<GlassTheme>(), settings.GlassTheme);
        DelaySlider.Value = settings.SelectionDelay;
        BubbleScaleSlider.Value = settings.BubbleScale;
        FontSizeSlider.Value = settings.TranslationFontSize;
        ShowSourceBox.IsChecked = settings.ShowSourceText;
        LaunchAtLoginBox.IsChecked = settings.LaunchAtLogin;
        SourceInitialized += (_, _) => WindowEffects.ApplyGlass(new WindowInteropHelper(this).Handle);
    }

    private void Save_OnClick(object sender, RoutedEventArgs e)
    {
        try
        {
            _settings.FreeServiceEmail = FreeEmailBox.Text;
            _settings.TargetLanguage = (LanguageBox.SelectedItem as LanguageOption)?.Value ?? TargetLanguage.Automatic;
            _settings.SelectionMethod = (SelectionMethodBox.SelectedItem as Option<SelectionMethod>)?.Value ?? SelectionMethod.Automatic;
            _settings.SelectionDelay = DelaySlider.Value;
            _settings.BubbleScale = BubbleScaleSlider.Value;
            _settings.BubblePosition = (BubblePositionBox.SelectedItem as Option<BubblePosition>)?.Value ?? BubblePosition.Below;
            _settings.GlassTheme = (ThemeBox.SelectedItem as Option<GlassTheme>)?.Value ?? GlassTheme.Aurora;
            _settings.TranslationFontSize = FontSizeSlider.Value;
            _settings.ShowSourceText = ShowSourceBox.IsChecked == true;
            _settings.LaunchAtLogin = LaunchAtLoginBox.IsChecked == true;
            _settings.Save();
            StatusText.Foreground = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(55, 117, 86));
            StatusText.Text = "已保存";
            SettingsSaved?.Invoke();
        }
        catch (Exception error)
        {
            StatusText.Foreground = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(184, 65, 65));
            StatusText.Text = error.Message;
        }
    }

    private void Restore_OnClick(object sender, RoutedEventArgs e)
    {
        SelectionMethodBox.SelectedIndex = 0;
        DelaySlider.Value = 0.18;
        BubbleScaleSlider.Value = 1.0;
        BubblePositionBox.SelectedIndex = 0;
        ThemeBox.SelectedIndex = 3;
        FontSizeSlider.Value = 16;
        ShowSourceBox.IsChecked = true;
        StatusText.Text = "已恢复推荐值，点击保存生效";
    }

    private void Window_OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.LeftButton == MouseButtonState.Pressed) DragMove();
    }

    private void Close_OnClick(object sender, RoutedEventArgs e) => Close();
}
