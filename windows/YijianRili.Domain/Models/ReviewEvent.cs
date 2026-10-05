using YijianRili.Domain.Services;

namespace YijianRili.Domain.Models;

/// <summary>复习事件模型；日期计算与 macOS ReviewEvent.calculateReviewDates 对齐。</summary>
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

    /// <summary>
    /// 按间隔天数从基准日推算复习日期。失败的间隔安全跳过（与 Swift 一致）。
    /// </summary>
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
                // 与 Swift Logger.warning + skip 行为一致：不抛出
            }
        }

        return dates;
    }
}

/// <summary>复习备注文案（「第N次复习」）。</summary>
public static class ReviewNoteText
{
    public static string ForIndex(int zeroBasedIndex)
        => $"第{zeroBasedIndex + 1}次复习";
}
