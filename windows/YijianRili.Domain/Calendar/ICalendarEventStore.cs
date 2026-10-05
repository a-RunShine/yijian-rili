namespace YijianRili.Domain.Calendar;

/// <summary>store seam 上可比对的已存事件字段。</summary>
public sealed class StoredCalendarEvent
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public DateTime Day { get; init; }
    public string RawNotes { get; init; } = string.Empty;
}

/// <summary>窄日历 store seam：查找某日事件 + 保存全天事件。</summary>
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
