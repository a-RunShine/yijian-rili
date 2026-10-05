namespace YijianRili.Domain.Services;

/// <summary>
/// 周次计算工具（对齐 macOS WeekCalculator）。
/// 周首日固定周一；使用本地时区的 DateTime（Kind 不强制 UTC）。
/// </summary>
public static class WeekCalculator
{
    /// <summary>返回 date 所在周的周一 00:00:00.000（本地日历日）。</summary>
    public static DateTime WeekStart(DateTime date)
    {
        var day = date.Date;
        // DayOfWeek: Sunday=0 ... Saturday=6
        var daysFromMonday = ((int)day.DayOfWeek + 6) % 7; // Mon=0 ... Sun=6
        return day.AddDays(-daysFromMonday);
    }

    /// <summary>返回 date 所在周的周日 23:59:59.999。</summary>
    public static DateTime WeekEnd(DateTime date)
    {
        var start = WeekStart(date);
        var sunday = start.AddDays(6);
        return new DateTime(sunday.Year, sunday.Month, sunday.Day, 23, 59, 59, 999, date.Kind);
    }

    public static string WeekKey(DateTime mondayStart)
        => mondayStart.Date.ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);

    public static (DateTime Start, DateTime End, string Key) WeekRange(DateTime date)
    {
        var start = WeekStart(date);
        var end = WeekEnd(date);
        return (start, end, WeekKey(start));
    }

    public static DateTime AddingWeeks(int n, DateTime mondayStart)
        => mondayStart.Date.AddDays(n * 7);

    public static bool IsWeekend(DateTime date)
    {
        var dow = date.DayOfWeek;
        return dow is DayOfWeek.Saturday or DayOfWeek.Sunday;
    }

    /// <summary>下一周周一 00:00（相对 date 所在周）。</summary>
    public static DateTime NextWeekMonday(DateTime date)
        => AddingWeeks(1, WeekStart(date));
}
