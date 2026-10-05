using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Windows.UI;
using YijianRili.Domain.Models;

namespace YijianRili.App.Services;

/// <summary>把 AppTheme 应用到 WinUI 视觉树。</summary>
public static class ThemeApplier
{
    public static void Apply(FrameworkElement root, AppTheme theme)
    {
        root.RequestedTheme = theme switch
        {
            AppTheme.Dark => ElementTheme.Dark,
            AppTheme.System => ElementTheme.Default,
            _ => ElementTheme.Light
        };

        if (root is Panel panel)
        {
            panel.Background = theme switch
            {
                AppTheme.LetterPaper => new SolidColorBrush(Color.FromArgb(255, 252, 247, 232)),
                AppTheme.Claude => new SolidColorBrush(Color.FromArgb(255, 240, 238, 230)),
                AppTheme.Dark => new SolidColorBrush(Color.FromArgb(255, 32, 32, 32)),
                _ => new SolidColorBrush(Colors.Transparent)
            };
        }

        // Claude 强调色
        if (Application.Current.Resources is ResourceDictionary resources)
        {
            if (theme == AppTheme.Claude)
            {
                resources["AppAccentBrush"] = new SolidColorBrush(Color.FromArgb(255, 217, 119, 87));
            }
            else
            {
                resources["AppAccentBrush"] = new SolidColorBrush(Color.FromArgb(255, 0, 120, 212));
            }
        }
    }
}
