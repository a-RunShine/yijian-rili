using YijianRili.Domain.Models;
using YijianRili.Domain.Services;

namespace YijianRili.Domain.Calendar;

/// <summary>进程内日历，供单测与无权限环境验证流程。</summary>
public sealed class InMemoryCalendarService : ICalendarService
{
    private readonly List<CalendarInfo> _calendars;
    private readonly List<CalendarEventInfo> _events = new();
    private readonly List<string> _lastCreated = new();
    private int _seq;

    public InMemoryCalendarService(bool grantAccessByDefault = true)
    {
        AuthorizationStatus = grantAccessByDefault
            ? CalendarAccessStatus.FullAccess
            : CalendarAccessStatus.NotDetermined;

        _calendars =
        [
            new CalendarInfo
            {
                Id = "local-default",
                Title = "本地日历",
                SourceTitle = "本地",
                SourceKind = CalendarSourceKind.Local
            },
            new CalendarInfo
            {
                Id = "outlook-default",
                Title = "日历",
                SourceTitle = "Outlook",
                SourceKind = CalendarSourceKind.Cloud
            }
        ];
    }

    public CalendarAccessStatus AuthorizationStatus { get; private set; }

    public IReadOnlyList<CalendarInfo> AvailableCalendars =>
        AuthorizationStatus == CalendarAccessStatus.FullAccess
            ? SortCalendars(_calendars)
            : Array.Empty<CalendarInfo>();

    public bool HasCloudCalendar =>
        AvailableCalendars.Any(c => c.SourceKind == CalendarSourceKind.Cloud);

    public IReadOnlyList<string> LastCreatedEventIdentifiers => _lastCreated.ToArray();

    public Task<bool> RequestAccessAsync(CancellationToken cancellationToken = default)
    {
        AuthorizationStatus = CalendarAccessStatus.FullAccess;
        return Task.FromResult(true);
    }

    public void RefreshAvailableCalendars() { /* no-op */ }

    public CalendarInfo? GetCalendar(string identifier)
        => AvailableCalendars.FirstOrDefault(c => c.Id == identifier);

    public CalendarInfo? GetDefaultCalendar()
        => AvailableCalendars.FirstOrDefault(c => c.SourceKind == CalendarSourceKind.Cloud)
           ?? AvailableCalendars.FirstOrDefault();

    public async Task<CreateEventsResult> CreateReviewEventsAsync(
        string title,
        DateTime baseDate,
        IReadOnlyList<int> intervals,
        string? calendarId = null,
        CancellationToken cancellationToken = default)
    {
        EnsureAccess();
        var calendar = ResolveCalendar(calendarId);
        var dates = ReviewEvent.CalculateReviewDates(baseDate, intervals);
        var result = new CreateEventsResult();
        var createdIds = new List<string>();

        for (var i = 0; i < dates.Count; i++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var date = dates[i];
            var notes = ReviewNoteText.ForIndex(i);
            if (HasDuplicate(title, date, notes, calendar.Id))
                result.Duplicates.Add(date);

            var id = $"evt-{++_seq}";
            _events.Add(new CalendarEventInfo
            {
                Id = id,
                Title = title,
                Start = date.Date,
                End = date.Date.AddDays(1),
                IsAllDay = true,
                Notes = notes,
                CalendarId = calendar.Id,
                CalendarTitle = calendar.Title
            });
            result.Created.Add(date);
            createdIds.Add(id);
            await Task.Yield();
        }

        if (createdIds.Count > 0)
        {
            _lastCreated.Clear();
            _lastCreated.AddRange(createdIds);
        }

        return result;
    }

    public async Task<CreateEventsResult> CreateSingleEventAsync(
        string title,
        DateTime date,
        string? calendarId = null,
        CancellationToken cancellationToken = default)
    {
        EnsureAccess();
        var calendar = ResolveCalendar(calendarId);
        var result = new CreateEventsResult();
        var day = date.Date;

        if (HasDuplicate(title, day, string.Empty, calendar.Id))
            result.Duplicates.Add(day);

        var id = $"evt-{++_seq}";
        _events.Add(new CalendarEventInfo
        {
            Id = id,
            Title = title,
            Start = day,
            End = day.AddDays(1),
            IsAllDay = true,
            Notes = string.Empty,
            CalendarId = calendar.Id,
            CalendarTitle = calendar.Title
        });
        result.Created.Add(day);
        _lastCreated.Clear();
        _lastCreated.Add(id);
        await Task.Yield();
        return result;
    }

    public Task<UndoResult> UndoLastCreationAsync(CancellationToken cancellationToken = default)
    {
        var deleted = 0;
        var missing = 0;
        foreach (var id in _lastCreated.ToArray())
        {
            var n = _events.RemoveAll(e => e.Id == id);
            if (n > 0) deleted += n;
            else missing++;
        }

        _lastCreated.Clear();
        return Task.FromResult(new UndoResult
        {
            Success = deleted > 0,
            DeletedCount = deleted,
            AlreadyDeletedCount = missing
        });
    }

    public Task<IReadOnlyList<CalendarEventInfo>> FetchEventsAsync(
        DateTime date,
        CancellationToken cancellationToken = default)
    {
        if (AuthorizationStatus != CalendarAccessStatus.FullAccess)
            return Task.FromResult<IReadOnlyList<CalendarEventInfo>>(Array.Empty<CalendarEventInfo>());

        var start = date.Date;
        var end = start.AddDays(1);
        var list = _events
            .Where(e => e.Start < end && e.End > start)
            .OrderByDescending(e => e.IsAllDay)
            .ThenBy(e => e.Start)
            .ToList();
        return Task.FromResult<IReadOnlyList<CalendarEventInfo>>(list);
    }

    public Task<bool> DeleteEventAsync(string eventId, CancellationToken cancellationToken = default)
    {
        var n = _events.RemoveAll(e => e.Id == eventId);
        return Task.FromResult(n > 0);
    }

    public Task<IReadOnlyList<CalendarEventInfo>> SearchEventsAsync(
        string query,
        int daysAhead = 90,
        CancellationToken cancellationToken = default)
    {
        var trimmed = query.Trim();
        if (trimmed.Length == 0 || AuthorizationStatus != CalendarAccessStatus.FullAccess)
            return Task.FromResult<IReadOnlyList<CalendarEventInfo>>(Array.Empty<CalendarEventInfo>());

        var start = DateTime.Today;
        var end = start.AddDays(daysAhead);
        var list = _events
            .Where(e => e.Start >= start && e.Start < end)
            .Where(e => e.Title.Contains(trimmed, StringComparison.CurrentCultureIgnoreCase))
            .OrderBy(e => e.Start)
            .ToList();
        return Task.FromResult<IReadOnlyList<CalendarEventInfo>>(list);
    }

    private void EnsureAccess()
    {
        if (AuthorizationStatus != CalendarAccessStatus.FullAccess)
            throw new CalendarServiceException("日历权限未授予");
    }

    private CalendarInfo ResolveCalendar(string? calendarId)
    {
        if (!string.IsNullOrEmpty(calendarId))
        {
            var chosen = GetCalendar(calendarId);
            if (chosen is not null) return chosen;
        }

        return GetDefaultCalendar()
               ?? throw new CalendarServiceException("默认日历不可用");
    }

    private bool HasDuplicate(string title, DateTime date, string notes, string calendarId)
    {
        var start = date.Date;
        var end = start.AddDays(1);
        return _events.Any(e =>
            e.CalendarId == calendarId &&
            e.Start >= start && e.Start < end &&
            e.Title == title &&
            (e.Notes ?? string.Empty) == notes);
    }

    private static IReadOnlyList<CalendarInfo> SortCalendars(IEnumerable<CalendarInfo> calendars)
        => calendars
            .OrderBy(c => c.SourceKind == CalendarSourceKind.Local ? 1 : 0)
            .ThenBy(c => c.SourceTitle, StringComparer.CurrentCulture)
            .ThenBy(c => c.Title, StringComparer.CurrentCulture)
            .ToList();
}
