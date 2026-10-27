using YijianRili.Domain.Services;

namespace YijianRili.Domain.Tests;

public class WeekCalculatorTests
{
    [Fact]
    public void WeekStart_IsMonday()
    {
        var sunday = new DateTime(2026, 10, 4);
        Assert.Equal(new DateTime(2026, 9, 28), WeekCalculator.WeekStart(sunday));
        Assert.Equal(DayOfWeek.Monday, WeekCalculator.WeekStart(sunday).DayOfWeek);

        Assert.Equal(new DateTime(2026, 10, 5), WeekCalculator.WeekStart(new DateTime(2026, 10, 5)));
    }

    [Fact]
    public void WeekEnd_IsSundayAlmostMidnight()
    {
        var monday = new DateTime(2026, 9, 28);
        var end = WeekCalculator.WeekEnd(monday);
        Assert.Equal(new DateTime(2026, 10, 4, 23, 59, 59, 999), end);
    }

    [Fact]
    public void IsWeekend_SatSunOnly()
    {
        Assert.True(WeekCalculator.IsWeekend(new DateTime(2026, 10, 3)));
        Assert.True(WeekCalculator.IsWeekend(new DateTime(2026, 10, 4)));
        Assert.False(WeekCalculator.IsWeekend(new DateTime(2026, 10, 5)));
        Assert.False(WeekCalculator.IsWeekend(new DateTime(2026, 9, 28)));
        Assert.False(WeekCalculator.IsWeekend(new DateTime(2026, 10, 2)));
    }

    [Fact]
    public void NextWeekMonday()
    {
        var friday = new DateTime(2026, 10, 2);
        Assert.Equal(new DateTime(2026, 10, 5), WeekCalculator.NextWeekMonday(friday));
    }

    [Fact]
    public void WeekKey_IsoDate()
    {
        Assert.Equal("2026-09-28", WeekCalculator.WeekKey(new DateTime(2026, 9, 28)));
    }
}
