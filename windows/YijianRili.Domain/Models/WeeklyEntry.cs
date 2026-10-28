using System.Text.Json.Serialization;

namespace YijianRili.Domain.Models;

public sealed class WeeklyEntry
{
    public Guid Id { get; init; }
    public required string Title { get; init; }
    public DateTime BaseDate { get; init; }

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ScheduleType ScheduleType { get; init; }

    public DateTime CreationDate { get; init; }

    public bool IsPreOccupiedNextWeek { get; init; }
}
