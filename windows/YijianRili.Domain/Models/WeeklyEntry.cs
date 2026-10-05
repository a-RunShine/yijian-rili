using System.Text.Json.Serialization;

namespace YijianRili.Domain.Models;

/// <summary>周末总结中的一条学习条目（永久保存，不受历史 20 条上限约束）。</summary>
public sealed class WeeklyEntry
{
    public Guid Id { get; init; }
    public required string Title { get; init; }
    public DateTime BaseDate { get; init; }

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ScheduleType ScheduleType { get; init; }

    public DateTime CreationDate { get; init; }

    /// <summary>周末复习计划双份规则下的下一周预占位标记；旧数据缺省 false。</summary>
    public bool IsPreOccupiedNextWeek { get; init; }
}
