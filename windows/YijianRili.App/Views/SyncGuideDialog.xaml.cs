using Microsoft.UI.Xaml.Controls;
using Windows.System;

namespace YijianRili.App.Views;

public sealed partial class SyncGuideDialog : ContentDialog
{
    public SyncGuideDialog()
    {
        InitializeComponent();
    }

    private async void OpenSettings_Click(ContentDialog sender, ContentDialogButtonClickEventArgs args)
    {
        // Windows 设置：账户
        await Launcher.LaunchUriAsync(new Uri("ms-settings:emailandaccounts"));
    }

    private async void OpenCalendar_Click(ContentDialog sender, ContentDialogButtonClickEventArgs args)
    {
        // 系统日历协议
        await Launcher.LaunchUriAsync(new Uri("outlookcal:"));
    }
}
