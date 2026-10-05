namespace YijianRili.Domain.Services;

/// <summary>复习间隔校验（对齐 ReviewViewModel.validateIntervals）。</summary>
public static class IntervalRules
{
    public static readonly IReadOnlyList<int> DefaultIntervals = new[] { 3, 7, 30 };

    public const int MinIntervalDays = 1;
    public const int MaxIntervalDays = 365;
    public const int MaxIntervalCount = 10;

    /// <summary>
    /// 非空、≤10 个、每个 1–365、严格递增。
    /// </summary>
    public static bool Validate(IReadOnlyList<int> intervals)
    {
        if (intervals is null || intervals.Count == 0) return false;
        if (intervals.Count > MaxIntervalCount) return false;
        if (intervals.Any(i => i < MinIntervalDays || i > MaxIntervalDays)) return false;
        for (var i = 1; i < intervals.Count; i++)
        {
            if (intervals[i] <= intervals[i - 1]) return false;
        }

        return true;
    }
}
