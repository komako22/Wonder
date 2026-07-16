using System.Runtime.InteropServices;
using System.Windows.Automation;
using System.Windows.Threading;
using GlassTranslate.Windows.Interop;
using GlassTranslate.Windows.Models;
using UiPoint = System.Windows.Point;
using UiRect = System.Windows.Rect;

namespace GlassTranslate.Windows.Services;

public sealed class SelectionMonitor : IDisposable
{
    private readonly Dispatcher _dispatcher;
    private readonly SettingsStore _settings;
    private readonly NativeMethods.LowLevelMouseProc _mouseCallback;
    private nint _mouseHook;
    private CancellationTokenSource? _pendingRead;
    private string _lastSignature = string.Empty;
    private UiPoint? _mouseDownPoint;
    private const double MinimumDragDistance = 4;
    private bool _disposed;

    public event Action? SelectionStarted;
    public event Action<SelectionSnapshot>? SelectionChanged;

    public SelectionMonitor(Dispatcher dispatcher, SettingsStore settings)
    {
        _dispatcher = dispatcher;
        _settings = settings;
        _mouseCallback = MouseHookCallback;
    }

    public void Start()
    {
        if (_mouseHook != 0) return;
        _mouseHook = NativeMethods.SetWindowsHookEx(
            NativeMethods.WhMouseLl,
            _mouseCallback,
            NativeMethods.GetModuleHandle(null),
            0);
        if (_mouseHook == 0)
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "无法启动全局划词监听。");
    }

    private nint MouseHookCallback(int code, nint message, nint data)
    {
        if (code >= 0 && !_disposed)
        {
            if (message == NativeMethods.WmLButtonDown)
            {
                var hookData = Marshal.PtrToStructure<NativeMethods.MsLlHookStruct>(data);
                _mouseDownPoint = new UiPoint(hookData.Point.X, hookData.Point.Y);
                _pendingRead?.Cancel();
                _lastSignature = string.Empty;
                _dispatcher.BeginInvoke(() => SelectionStarted?.Invoke());
            }
            else if (message == NativeMethods.WmLButtonUp)
            {
                var hookData = Marshal.PtrToStructure<NativeMethods.MsLlHookStruct>(data);
                var point = new UiPoint(hookData.Point.X, hookData.Point.Y);
                var distance = _mouseDownPoint is { } start
                    ? Math.Sqrt(Math.Pow(point.X - start.X, 2) + Math.Pow(point.Y - start.Y, 2))
                    : 0;
                _mouseDownPoint = null;
                if (distance >= MinimumDragDistance)
                    ScheduleRead(hookData.Point.X, hookData.Point.Y);
            }
        }
        return NativeMethods.CallNextHookEx(_mouseHook, code, message, data);
    }

    private void ScheduleRead(int x, int y)
    {
        _pendingRead?.Cancel();
        var cancellation = new CancellationTokenSource();
        _pendingRead = cancellation;
        _ = Task.Run(async () =>
        {
            try
            {
                await Task.Delay(TimeSpan.FromSeconds(Math.Max(0.05, _settings.SelectionDelay)), cancellation.Token);
                var inner = await _dispatcher.InvokeAsync(
                    () => ReadSelectionAsync(x, y),
                    DispatcherPriority.Background,
                    cancellation.Token);
                await inner;
            }
            catch (OperationCanceledException) { }
        }, cancellation.Token);
    }

    private async Task ReadSelectionAsync(int x, int y)
    {
        var elements = new List<AutomationElement>();
        try
        {
            var pointed = AutomationElement.FromPoint(new UiPoint(x, y));
            if (pointed is not null) elements.Add(pointed);
        }
        catch (ElementNotAvailableException) { }
        catch (COMException) { }

        try
        {
            var focused = AutomationElement.FocusedElement;
            if (focused is not null) elements.Add(focused);
        }
        catch (ElementNotAvailableException) { }
        catch (COMException) { }

        foreach (var initial in elements)
        {
            AutomationElement? element = initial;
            for (var depth = 0; depth < 8 && element is not null; depth++)
            {
                var snapshot = TryRead(element, x, y);
                if (EmitIfNew(snapshot)) return;
                try { element = TreeWalker.ControlViewWalker.GetParent(element); }
                catch (ElementNotAvailableException) { element = null; }
                catch (COMException) { element = null; }
            }
        }
    }

    private bool EmitIfNew(SelectionSnapshot? snapshot)
    {
        if (snapshot is null || snapshot.Signature == _lastSignature) return false;
        _lastSignature = snapshot.Signature;
        SelectionChanged?.Invoke(snapshot);
        return true;
    }

    private static SelectionSnapshot? TryRead(AutomationElement element, int pointerX, int pointerY)
    {
        try
        {
            if (element.Current.IsPassword) return null;
            if (!element.TryGetCurrentPattern(TextPattern.Pattern, out var rawPattern) || rawPattern is not TextPattern pattern)
                return null;

            foreach (var range in pattern.GetSelection())
            {
                var text = range.GetText(8_001).Trim();
                if (text.Length is 0 or > 8_000) continue;
                var bounds = range.GetBoundingRectangles();
                var rect = BoundsFromRectangles(bounds) ?? new UiRect(pointerX - 4, pointerY - 4, 8, 8);
                return new SelectionSnapshot(text, rect);
            }
        }
        catch (ElementNotAvailableException) { }
        catch (InvalidOperationException) { }
        catch (COMException) { }
        return null;
    }

    private static UiRect? BoundsFromRectangles(UiRect[] values)
    {
        if (values.Length == 0) return null;
        var left = double.PositiveInfinity;
        var top = double.PositiveInfinity;
        var right = double.NegativeInfinity;
        var bottom = double.NegativeInfinity;
        foreach (var value in values)
        {
            if (value.Width <= 0 || value.Height <= 0) continue;
            left = Math.Min(left, value.Left);
            top = Math.Min(top, value.Top);
            right = Math.Max(right, value.Right);
            bottom = Math.Max(bottom, value.Bottom);
        }
        return double.IsInfinity(left) ? null : new UiRect(left, top, right - left, bottom - top);
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _pendingRead?.Cancel();
        if (_mouseHook != 0)
        {
            _ = NativeMethods.UnhookWindowsHookEx(_mouseHook);
            _mouseHook = 0;
        }
        GC.SuppressFinalize(this);
    }
}
