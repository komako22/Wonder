using System.Drawing;
using System.Threading;
using System.Windows;
using GlassTranslate.Windows.Models;
using GlassTranslate.Windows.Services;
using GlassTranslate.Windows.Views;
using Forms = System.Windows.Forms;

namespace GlassTranslate.Windows;

public partial class App : System.Windows.Application
{
    private Mutex? _singleInstance;
    private SettingsStore? _settings;
    private SelectionMonitor? _selectionMonitor;
    private Forms.NotifyIcon? _trayIcon;
    private Forms.ToolStripMenuItem? _pauseMenuItem;
    private BubbleWindow? _bubble;
    private ResultWindow? _result;
    private SettingsWindow? _settingsWindow;

    protected override void OnStartup(StartupEventArgs e)
    {
        _singleInstance = new Mutex(true, @"Local\Wonder.Desktop", out var created);
        if (!created)
        {
            Shutdown();
            return;
        }

        base.OnStartup(e);
        _settings = new SettingsStore();
        _settings.Load();
        ConfigureTray();

        _selectionMonitor = new SelectionMonitor(Dispatcher, _settings);
        _selectionMonitor.SelectionStarted += () =>
        {
            _bubble?.Close();
            _bubble = null;
        };
        _selectionMonitor.SelectionChanged += ShowBubble;
        try
        {
            _selectionMonitor.Start();
        }
        catch (Exception error)
        {
            Forms.MessageBox.Show(error.Message, "Wonder", Forms.MessageBoxButtons.OK, Forms.MessageBoxIcon.Error);
        }

    }

    private void ConfigureTray()
    {
        if (_settings is null) return;
        var menu = new Forms.ContextMenuStrip();
        _pauseMenuItem = new Forms.ToolStripMenuItem(PauseTitle(), null, (_, _) => TogglePaused());
        menu.Items.Add(_pauseMenuItem);
        menu.Items.Add("设置…", null, (_, _) => Dispatcher.Invoke(ShowSettings));
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("退出 Wonder", null, (_, _) => Dispatcher.Invoke(ExitApplication));

        _trayIcon = new Forms.NotifyIcon
        {
            Text = "Wonder",
            Icon = LoadAppIcon(),
            ContextMenuStrip = menu,
            Visible = true
        };
        _trayIcon.DoubleClick += (_, _) => Dispatcher.Invoke(ShowSettings);
    }

    private static Icon LoadAppIcon()
    {
        try
        {
            return Icon.ExtractAssociatedIcon(Environment.ProcessPath ?? string.Empty) ?? SystemIcons.Application;
        }
        catch
        {
            return SystemIcons.Application;
        }
    }

    private string PauseTitle() => _settings?.IsPaused == true ? "继续划词监听" : "暂停划词监听";

    private void TogglePaused()
    {
        Dispatcher.Invoke(() =>
        {
            if (_settings is null) return;
            _settings.IsPaused = !_settings.IsPaused;
            _settings.Save();
            if (_pauseMenuItem is not null) _pauseMenuItem.Text = PauseTitle();
            if (_settings.IsPaused)
            {
                _bubble?.Close();
                _result?.Close();
            }
        });
    }

    private void ShowBubble(SelectionSnapshot selection)
    {
        if (_settings is null || _settings.IsPaused) return;
        _bubble?.Close();
        _bubble = new BubbleWindow(selection, _settings, () =>
        {
            _bubble?.Close();
            _bubble = null;
            _result?.Close();
            _result = new ResultWindow(selection, _settings);
            _result.Closed += (_, _) => _result = null;
            _result.Show();
            _result.Activate();
        });
        _bubble.Show();
    }

    private void ShowSettings()
    {
        if (_settings is null) return;
        if (_settingsWindow is null)
        {
            _settingsWindow = new SettingsWindow(_settings);
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
            _settingsWindow.SettingsSaved += () =>
            {
                if (_pauseMenuItem is not null) _pauseMenuItem.Text = PauseTitle();
            };
        }
        _settingsWindow.Show();
        _settingsWindow.Activate();
    }

    private void ExitApplication()
    {
        _selectionMonitor?.Dispose();
        _trayIcon?.Dispose();
        _singleInstance?.ReleaseMutex();
        _singleInstance?.Dispose();
        Shutdown();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _selectionMonitor?.Dispose();
        _trayIcon?.Dispose();
        base.OnExit(e);
    }
}
