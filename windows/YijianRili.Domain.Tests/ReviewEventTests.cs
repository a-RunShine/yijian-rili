using YijianRili.Domain.Models;

namespace YijianRili.Domain.Tests;

public class ReviewEventTests
{
    [Fact]
    public void CalculateReviewDates_DefaultIntervals()
    {
        var baseDate = new DateTime(2026, 6, 22);
        var dates = ReviewEvent.CalculateReviewDates(baseDate);
        Assert.Equal(new[]
        {
            new DateTime(2026, 6, 25),
            new DateTime(2026, 6, 29),
            new DateTime(2026, 7, 22)
        }, dates);
    }

    [Fact]
    public void CalculateReviewDates_CrossYear()
    {
        var baseDate = new DateTime(2025, 12, 20);
        var dates = ReviewEvent.CalculateReviewDates(baseDate, new[] { 3, 7, 30 });
        Assert.Equal(new DateTime(2025, 12, 23), dates[0]);
        Assert.Equal(new DateTime(2025, 12, 27), dates[1]);
        Assert.Equal(new DateTime(2026, 1, 19), dates[2]);
    }

    [Fact]
    public void CalculateReviewDates_LeapYear()
    {
        var baseDate = new DateTime(2024, 2, 27);
        var dates = ReviewEvent.CalculateReviewDates(baseDate, new[] { 1, 2 });
        Assert.Equal(new DateTime(2024, 2, 28), dates[0]);
        Assert.Equal(new DateTime(2024, 2, 29), dates[1]);
    }

    [Fact]
    public void ReviewEvent_NotesAlignWithDates()
    {
        var evt = new ReviewEvent("英语", new DateTime(2026, 1, 1), new[] { 1, 2 });
        Assert.Equal(2, evt.Notes.Count);
        Assert.Equal("第1次复习", evt.Notes[0]);
        Assert.Equal("第2次复习", evt.Notes[1]);
    }
}
