namespace YijianRili.Domain.Services;

public static class WeekCalculator
{
    public static DateTime WeekStart(DateTime date)
    {
        var day = date.Date;
        var daysFromMonday = ((int)day.DayOfWeek + 6) % 7;
        return day.AddDays(-daysFromMonday);
    }

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

    public static DateTime NextWeekMonday(DateTime date)
        => AddingWeeks(1, WeekStart(date));
}
