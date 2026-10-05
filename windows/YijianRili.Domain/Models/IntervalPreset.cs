using YijianRili.Domain.Services;

namespace YijianRili.Domain.Models;

/// <summary>内置间隔预设（对齐 macOS IntervalPreset）。</summary>
public enum IntervalPreset
{
    Classic,
    Exam,
    Daily
}

public static class IntervalPresetExtensions
{
    public static string DisplayName(this IntervalPreset preset) => preset switch
    {
        IntervalPreset.Classic => "经典艾宾浩斯",
        IntervalPreset.Exam => "考试冲刺",
        IntervalPreset.Daily => "日常复习",
        _ => preset.ToString()
    };

    public static IReadOnlyList<int> Intervals(this IntervalPreset preset) => preset switch
    {
        IntervalPreset.Classic => new[] { 1, 2, 4, 7, 15 },
        IntervalPreset.Exam => new[] { 1, 3, 7 },
        IntervalPreset.Daily => new[] { 3, 7, 30 },
        _ => IntervalRules.DefaultIntervals
    };
}
