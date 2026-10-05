namespace YijianRili.Domain.Models;

public enum AppTheme
{
    Light,
    Dark,
    LetterPaper,
    Claude,
    System
}

public static class AppThemeExtensions
{
    public static string DisplayName(this AppTheme theme) => theme switch
    {
        AppTheme.Light => "浅色",
        AppTheme.Dark => "深色",
        AppTheme.LetterPaper => "信纸",
        AppTheme.Claude => "Claude",
        AppTheme.System => "跟随系统",
        _ => theme.ToString()
    };

    public static string StorageKey(this AppTheme theme) => theme switch
    {
        AppTheme.Light => "light",
        AppTheme.Dark => "dark",
        AppTheme.LetterPaper => "letterPaper",
        AppTheme.Claude => "claude",
        AppTheme.System => "system",
        _ => "light"
    };

    public static AppTheme FromStorageKey(string? raw) => raw switch
    {
        "dark" => AppTheme.Dark,
        "letterPaper" => AppTheme.LetterPaper,
        "claude" => AppTheme.Claude,
        "system" => AppTheme.System,
        _ => AppTheme.Light
    };
}
