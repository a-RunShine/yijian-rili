using YijianRili.Domain.Models;
using YijianRili.Domain.Services;

namespace YijianRili.Domain.Calendar;

/// <summary>写入日历编排产出。</summary>
public sealed class CalendarWriteOutcome
{
    public CreateEventsResult Result { get; init; } = new();
    public IReadOnlyList<string> CreatedEventIds { get; init; } = Array.Empty<string>();
}

/// <summary>
/// 写入日历编排：校验间隔 → 算日 → 备注键 → 重复检测 → 经 store 写入。
/// </summary>
public static class CalendarWriteOrchestrator
{
    public static async Task<CalendarWriteOutcome> WriteReviewAsync(
        string title,
        DateTime baseDate,
        IReadOnlyList<int> intervals,
        string calendarId,
        ICalendarEventStore store,
        CancellationToken cancellationToken = default)
    {
        if (!IntervalRules.Validate(intervals))
            throw new CalendarServiceException("无效的复习间隔");

        var dates = ReviewEvent.CalculateReviewDates(baseDate, intervals);
        var items = dates
            .Select((date, index) => (Date: date, NotesKey: ReviewNoteText.ForIndex(index)))
            .ToList();
        return await WriteAllDayEventsAsync(title, items, calendarId, store, cancellationToken)
            .ConfigureAwait(false);
    }

    public static Task<CalendarWriteOutcome> WriteSingleAsync(
        string title,
        DateTime date,
        string calendarId,
        ICalendarEventStore store,
        CancellationToken cancellationToken = default)
    {
        var day = date.Date;
        var items = new[] { (Date: day, NotesKey: string.Empty) };
        return WriteAllDayEventsAsync(title, items, calendarId, store, cancellationToken);
    }

    public static async Task<CalendarWriteOutcome> WriteAllDayEventsAsync(
        string title,
        IReadOnlyList<(DateTime Date, string NotesKey)> items,
        string calendarId,
        ICalendarEventStore store,
        CancellationToken cancellationToken = default)
    {
        var result = new CreateEventsResult();
        var createdIds = new List<string>();

        foreach (var item in items)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var day = item.Date.Date;
            try
            {
                var existing = await store
                    .GetEventsAsync(calendarId, day, cancellationToken)
                    .ConfigureAwait(false);
                if (IsDuplicate(title, day, item.NotesKey, existing))
                    result.Duplicates.Add(day);

                var id = await store
                    .SaveAllDayAsync(calendarId, title, day, item.NotesKey, cancellationToken)
                    .ConfigureAwait(false);
                result.Created.Add(day);
                createdIds.Add(id);
            }
            catch (Exception ex)
            {
                result.Failed.Add((day, ex.Message));
            }
        }

        return new CalendarWriteOutcome
        {
            Result = result,
            CreatedEventIds = createdIds
        };
    }

    public static bool IsDuplicate(
        string title,
        DateTime day,
        string notesKey,
        IEnumerable<StoredCalendarEvent> existing)
    {
        var want = NormalizeNotes.Normalize(notesKey);
        var dayStart = day.Date;
        return existing.Any(e =>
            e.Day.Date == dayStart &&
            e.Title == title &&
            NormalizeNotes.Normalize(e.RawNotes) == want);
    }
}
