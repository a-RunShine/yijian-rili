namespace YijianRili.Domain.Services;

public sealed class WeeklyNotes
{
    public Dictionary<string, string> ByWeek { get; set; } = new(StringComparer.Ordinal);
}
