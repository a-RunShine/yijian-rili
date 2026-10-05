using System.Globalization;

namespace YijianRili.Domain.Services;

public static class DateFormats
{
    private static readonly CultureInfo ZhCn = CultureInfo.GetCultureInfo("zh-CN");

    public static string FormattedChinese(DateTime date)
        => date.ToString("yyyy年MM月dd日", ZhCn);

    public static string FormattedShort(DateTime date)
        => date.ToString("MM-dd", ZhCn);

    public static string FormattedTime(DateTime date)
        => date.ToString("HH:mm", ZhCn);

    /// <summary>全天事件的 9:00 提醒时刻。</summary>
    public static DateTime AlarmAtNine(DateTime day)
        => day.Date.AddHours(9);
}
