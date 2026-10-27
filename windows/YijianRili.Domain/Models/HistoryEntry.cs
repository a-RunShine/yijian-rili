using System.Text.Json.Serialization;

namespace YijianRili.Domain.Models;

public sealed class HistoryEntry
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public required string Title { get; init; }
    public DateTime BaseDate { get; init; }
    public IReadOnlyList<DateTime> ReviewDates { get; init; } = Array.Empty<DateTime>();
    public DateTime CreationDate { get; init; }

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ScheduleType Type { get; init; } = ScheduleType.Review;
}
