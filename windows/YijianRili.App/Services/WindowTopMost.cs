using System.Runtime.InteropServices;
using Microsoft.UI.Xaml;
using WinRT.Interop;

namespace YijianRili.App.Services;

/// <summary>HWND_TOPMOST 窗口置顶（对齐 macOS NSWindow.Level.floating）。</summary>
public static class WindowTopMost
{
    private static readonly IntPtr HwndTopMost = new(-1);
    private static readonly IntPtr HwndNoTopMost = new(-2);
    private const uint SwpNosize = 0x0001;
    private const uint SwpNomove = 0x0002;
    private const uint SwpNoactivate = 0x0010;
    private const uint SwpShowwindow = 0x0040;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(
        IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);

    public static void Apply(Window window, bool topMost)
    {
        var hwnd = WindowNative.GetWindowHandle(window);
        SetWindowPos(
            hwnd,
            topMost ? HwndTopMost : HwndNoTopMost,
            0, 0, 0, 0,
            SwpNomove | SwpNosize | SwpNoactivate | SwpShowwindow);
    }
}
