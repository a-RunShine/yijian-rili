using YijianRili.Domain.Services;

namespace YijianRili.Domain.Models;

public sealed class ReviewEvent
{
    public Guid Id { get; }
    public string Title { get; }
    public DateTime BaseDate { get; }
    public IReadOnlyList<DateTime> ReviewDates { get; }
    public IReadOnlyList<string> Notes { get; }

    public ReviewEvent(string title, DateTime baseDate, IReadOnlyList<int>? intervals = null)
    {
        Id = Guid.NewGuid();
        Title = title;
        BaseDate = baseDate.Date;
        var dates = CalculateReviewDates(BaseDate, intervals ?? IntervalRules.DefaultIntervals);
        ReviewDates = dates;
        Notes = dates.Select((_, index) => ReviewNoteText.ForIndex(index)).ToArray();
    }

    public static IReadOnlyList<DateTime> CalculateReviewDates(
        DateTime baseDate,
        IReadOnlyList<int>? intervals = null)
    {
        intervals ??= IntervalRules.DefaultIntervals;
        var start = baseDate.Date;
        var dates = new List<DateTime>(intervals.Count);
        foreach (var interval in intervals)
        {
            try
            {
                dates.Add(start.AddDays(interval));
            }
            catch (ArgumentOutOfRangeException)
            {
            }
        }

        return dates;
    }
}

public static class ReviewNoteText
{
    public static string ForIndex(int zeroBasedIndex)
        => $"第{zeroBasedIndex + 1}次复习";
}
