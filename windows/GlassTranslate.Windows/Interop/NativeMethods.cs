using System.Runtime.InteropServices;

namespace GlassTranslate.Windows.Interop;

internal static class NativeMethods
{
    internal const int WhMouseLl = 14;
    internal const int WmLButtonDown = 0x0201;
    internal const int WmLButtonUp = 0x0202;
    internal const int GwlExStyle = -20;
    internal const long WsExToolWindow = 0x00000080L;
    internal const long WsExNoActivate = 0x08000000L;

    internal delegate nint LowLevelMouseProc(int nCode, nint wParam, nint lParam);

    [StructLayout(LayoutKind.Sequential)]
    internal struct Point
    {
        internal int X;
        internal int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct MsLlHookStruct
    {
        internal Point Point;
        internal uint MouseData;
        internal uint Flags;
        internal uint Time;
        internal nuint ExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    internal static extern nint SetWindowsHookEx(int idHook, LowLevelMouseProc callback, nint module, uint threadId);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool UnhookWindowsHookEx(nint hook);

    [DllImport("user32.dll")]
    internal static extern nint CallNextHookEx(nint hook, int code, nint wParam, nint lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    internal static extern nint GetModuleHandle(string? moduleName);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    internal static extern nint GetWindowLongPtr(nint window, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")]
    internal static extern nint SetWindowLongPtr(nint window, int index, nint value);

    [DllImport("dwmapi.dll")]
    internal static extern int DwmSetWindowAttribute(nint window, int attribute, ref int value, int size);

    [DllImport("user32.dll")]
    internal static extern nint MonitorFromPoint(Point point, uint flags);

    [DllImport("shcore.dll")]
    internal static extern int GetDpiForMonitor(nint monitor, int dpiType, out uint dpiX, out uint dpiY);

}

internal static class DisplayCoordinates
{
    internal static (double X, double Y) ToDip(double physicalX, double physicalY)
    {
        var point = new NativeMethods.Point { X = (int)physicalX, Y = (int)physicalY };
        var monitor = NativeMethods.MonitorFromPoint(point, 2);
        if (monitor != 0 && NativeMethods.GetDpiForMonitor(monitor, 0, out var dpiX, out var dpiY) == 0)
            return (physicalX * 96d / dpiX, physicalY * 96d / dpiY);
        return (physicalX, physicalY);
    }
}

internal static class WindowEffects
{
    internal static void ApplyNoActivate(nint window)
    {
        var current = NativeMethods.GetWindowLongPtr(window, NativeMethods.GwlExStyle).ToInt64();
        NativeMethods.SetWindowLongPtr(
            window,
            NativeMethods.GwlExStyle,
            new nint(current | NativeMethods.WsExToolWindow | NativeMethods.WsExNoActivate));
    }

    internal static void ApplyGlass(nint window)
    {
        const int immersiveDarkMode = 20;
        const int cornerPreference = 33;
        const int systemBackdropType = 38;
        var enabled = 1;
        var rounded = 2;
        var transientWindow = 3;
        _ = NativeMethods.DwmSetWindowAttribute(window, immersiveDarkMode, ref enabled, sizeof(int));
        _ = NativeMethods.DwmSetWindowAttribute(window, cornerPreference, ref rounded, sizeof(int));
        _ = NativeMethods.DwmSetWindowAttribute(window, systemBackdropType, ref transientWindow, sizeof(int));
    }
}
