using System.Windows;
using System.Windows.Interop;
using System.Windows.Input;
using GlassTranslate.Windows.Interop;
using GlassTranslate.Windows.Models;
using GlassTranslate.Windows.Services;

namespace GlassTranslate.Windows.Views;

public partial class ResultWindow : Window
{
    private readonly SelectionSnapshot _selection;
    private readonly SettingsStore _settings;
    private readonly TranslationClient _client = new();
    private CancellationTokenSource? _request;

    public ResultWindow(SelectionSnapshot selection, SettingsStore settings)
    {
        InitializeComponent();
        _selection = selection;
        _settings = settings;
        SourceText.Text = selection.Text;
        SourcePanel.Visibility = settings.ShowSourceText ? Visibility.Visible : Visibility.Collapsed;
        ResultText.FontSize = settings.TranslationFontSize;
        ResultText.LineHeight = Math.Max(16, settings.TranslationFontSize + 1);
        SourceInitialized += (_, _) => WindowEffects.ApplyGlass(new WindowInteropHelper(this).Handle);
        Loaded += async (_, _) => await TranslateAsync();
        Deactivated += (_, _) => Close();
        Closed += (_, _) => _request?.Cancel();
        PositionNear(selection.ScreenRect);
    }

    private void PositionNear(Rect rect)
    {
        var anchor = DisplayCoordinates.ToDip(rect.Left + rect.Width / 2, rect.Bottom + 12);
        Left = Math.Max(8, anchor.X - Width / 2);
        Top = Math.Max(8, anchor.Y);
    }

    private async Task TranslateAsync()
    {
        _request?.Cancel();
        _request = new CancellationTokenSource();
        LoadingPanel.Visibility = Visibility.Visible;
        ResultPanel.Visibility = Visibility.Collapsed;
        ErrorPanel.Visibility = Visibility.Collapsed;
        try
        {
            ResultText.Text = await _client.TranslateAsync(_selection.Text, _settings, _request.Token);
            LoadingPanel.Visibility = Visibility.Collapsed;
            ResultPanel.Visibility = Visibility.Visible;
            ResizeForContent();
        }
        catch (OperationCanceledException) { }
        catch (Exception error)
        {
            LoadingPanel.Visibility = Visibility.Collapsed;
            ErrorPanel.Visibility = Visibility.Visible;
            ErrorText.Text = error.Message;
        }
    }

    private void ResizeForContent()
    {
        var contentWidth = Math.Max(280, Width - 64);
        ResultText.Measure(new Size(contentWidth, double.PositiveInfinity));
        var sourceHeight = SourcePanel.Visibility == Visibility.Visible
            ? Math.Min(62, SourcePanel.DesiredSize.Height)
            : 0;
        var desired = 134 + sourceHeight + ResultText.DesiredSize.Height;
        Height = Math.Clamp(desired, SourcePanel.Visibility == Visibility.Visible ? 220 : 180, 520);
        PositionNear(_selection.ScreenRect);
    }

    private void DragHandle_OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.LeftButton == MouseButtonState.Pressed) DragMove();
    }

    private void Close_OnClick(object sender, RoutedEventArgs e) => Close();

    private void Copy_OnClick(object sender, RoutedEventArgs e)
    {
        if (!string.IsNullOrWhiteSpace(ResultText.Text)) Clipboard.SetText(ResultText.Text);
    }

    private async void Retry_OnClick(object sender, RoutedEventArgs e) => await TranslateAsync();
}
