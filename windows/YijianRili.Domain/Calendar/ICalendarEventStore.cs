namespace YijianRili.Domain.Calendar;

public sealed class StoredCalendarEvent
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public DateTime Day { get; init; }
    public string RawNotes { get; init; } = string.Empty;
}

public interface ICalendarEventStore
{
    Task<IReadOnlyList<StoredCalendarEvent>> GetEventsAsync(
        string calendarId,
        DateTime day,
        CancellationToken cancellationToken = default);

    Task<string> SaveAllDayAsync(
        string calendarId,
        string title,
        DateTime day,
        string notesKey,
        CancellationToken cancellationToken = default);
}
