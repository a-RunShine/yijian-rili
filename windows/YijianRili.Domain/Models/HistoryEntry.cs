using System.Text.Json.Serialization;

namespace YijianRili.Domain.Models;

/// <summary>历史记录条目（上限由 HistoryStore 控制，默认 20）。</summary>
public sealed class HistoryEntry
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public required string Title { get; init; }
    public DateTime BaseDate { get; init; }
    public IReadOnlyList<DateTime> ReviewDates { get; init; } = Array.Empty<DateTime>();
    public DateTime CreationDate { get; init; }

    /// <summary>旧数据缺省时为 Review。</summary>
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ScheduleType Type { get; init; } = ScheduleType.Review;
}
