using Windows.ApplicationModel.Appointments;
using YijianRili.Domain.Calendar;
using YijianRili.Domain.Models;
using YijianRili.Domain.Services;

namespace YijianRili.Calendar;

/// <summary>
/// Windows.ApplicationModel.Appointments 实现，行为对齐 macOS CalendarManager。
/// </summary>
/// <remarks>
/// 提醒：WinRT 只支持「相对开始时间」的 Reminder。全天事件 Start 为当天 00:00，
/// 无法用 Reminder 精确表达「当天 09:00」。本实现采用全天事件，并在 Details
/// 中写入提醒建议；可靠响铃可后续改为 09:00 定时事件。
/// </remarks>
public sealed class WinRtCalendarService : ICalendarService
{
    private AppointmentStore? _store;
    private List<CalendarInfo> _calendars = new();
    private readonly List<string> _lastCreated = new();

    public CalendarAccessStatus AuthorizationStatus { get; private set; } = CalendarAccessStatus.NotDetermined;

    public IReadOnlyList<CalendarInfo> AvailableCalendars => SortCalendars(_calendars);

    public bool HasCloudCalendar => AvailableCalendars.Any(c => c.SourceKind == CalendarSourceKind.Cloud);

    public IReadOnlyList<string> LastCreatedEventIdentifiers => _lastCreated.ToArray();

    public async Task<bool> RequestAccessAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            _store = await AppointmentManager
                .RequestStoreAsync(AppointmentStoreAccessType.AllCalendarsReadWrite)
                .AsTask(cancellationToken)
                .ConfigureAwait(false);

            AuthorizationStatus = _store is null
                ? CalendarAccessStatus.Denied
                : CalendarAccessStatus.FullAccess;

            if (AuthorizationStatus == CalendarAccessStatus.FullAccess)
                await RefreshAvailableCalendarsAsync(cancellationToken).ConfigureAwait(false);

            return AuthorizationStatus == CalendarAccessStatus.FullAccess;
        }
        catch (UnauthorizedAccessException)
        {
            AuthorizationStatus = CalendarAccessStatus.Denied;
            return false;
        }
        catch (Exception)
        {
            AuthorizationStatus = CalendarAccessStatus.Denied;
            return false;
        }
    }

    public void RefreshAvailableCalendars()
        => _ = RefreshAvailableCalendarsAsync();

    public async Task RefreshAvailableCalendarsAsync(CancellationToken cancellationToken = default)
    {
        if (_store is null)
        {
            _calendars = new List<CalendarInfo>();
            return;
        }

        var winCalendars = await _store
            .FindAppointmentCalendarsAsync()
            .AsTask(cancellationToken)
            .ConfigureAwait(false);

        _calendars = winCalendars
            .Where(c => c.CanCreateOrUpdateAppointments)
            .Select(MapCalendar)
            .ToList();
    }

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
        var store = await EnsureStoreAsync(cancellationToken).ConfigureAwait(false);
        var calendar = await ResolveCalendarAsync(store, calendarId, cancellationToken).ConfigureAwait(false);
        var dates = ReviewEvent.CalculateReviewDates(baseDate, intervals);
        var result = new CreateEventsResult();
        var createdIds = new List<string>();

        for (var i = 0; i < dates.Count; i++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var date = dates[i];
            var notes = ReviewNoteText.ForIndex(i);
            try
            {
                if (await HasDuplicateAsync(store, title, date, notes, calendar.LocalId, cancellationToken)
                        .ConfigureAwait(false))
                {
                    result.Duplicates.Add(date);
                }

                var appointment = BuildAllDayAppointment(title, date, notes);
                await calendar.SaveAppointmentAsync(appointment).AsTask(cancellationToken).ConfigureAwait(false);
                result.Created.Add(date);
                if (!string.IsNullOrEmpty(appointment.LocalId))
                    createdIds.Add(appointment.LocalId);
            }
            catch (Exception ex)
            {
                result.Failed.Add((date, ex.Message));
            }
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
        var store = await EnsureStoreAsync(cancellationToken).ConfigureAwait(false);
        var calendar = await ResolveCalendarAsync(store, calendarId, cancellationToken).ConfigureAwait(false);
        var result = new CreateEventsResult();
        var day = date.Date;

        try
        {
            if (await HasDuplicateAsync(store, title, day, string.Empty, calendar.LocalId, cancellationToken)
                    .ConfigureAwait(false))
            {
                result.Duplicates.Add(day);
            }

            var appointment = BuildAllDayAppointment(title, day, string.Empty);
            await calendar.SaveAppointmentAsync(appointment).AsTask(cancellationToken).ConfigureAwait(false);
            result.Created.Add(day);
            _lastCreated.Clear();
            if (!string.IsNullOrEmpty(appointment.LocalId))
                _lastCreated.Add(appointment.LocalId);
        }
        catch (Exception ex)
        {
            result.Failed.Add((day, ex.Message));
        }

        return result;
    }

    public async Task<UndoResult> UndoLastCreationAsync(CancellationToken cancellationToken = default)
    {
        var store = _store ?? await EnsureStoreAsync(cancellationToken).ConfigureAwait(false);
        var deleted = 0;
        var missing = 0;

        foreach (var id in _lastCreated.ToArray())
        {
            try
            {
                var existing = await store.GetAppointmentAsync(id).AsTask(cancellationToken).ConfigureAwait(false);
                if (existing is null)
                {
                    missing++;
                    continue;
                }

                var calendar = await store
                    .GetAppointmentCalendarAsync(existing.CalendarId)
                    .AsTask(cancellationToken)
                    .ConfigureAwait(false);
                await calendar.DeleteAppointmentAsync(id).AsTask(cancellationToken).ConfigureAwait(false);
                deleted++;
            }
            catch
            {
                missing++;
            }
        }

        _lastCreated.Clear();
        return new UndoResult
        {
            Success = deleted > 0,
            DeletedCount = deleted,
            AlreadyDeletedCount = missing
        };
    }

    public async Task<IReadOnlyList<CalendarEventInfo>> FetchEventsAsync(
        DateTime date,
        CancellationToken cancellationToken = default)
    {
        if (AuthorizationStatus != CalendarAccessStatus.FullAccess || _store is null)
            return Array.Empty<CalendarEventInfo>();

        var start = new DateTimeOffset(date.Date);
        var duration = TimeSpan.FromDays(1);
        var findOptions = new FindAppointmentsOptions { MaxCount = 500 };

        var list = await _store
            .FindAppointmentsAsync(start, duration, findOptions)
            .AsTask(cancellationToken)
            .ConfigureAwait(false);

        return list
            .Select(MapEvent)
            .OrderByDescending(e => e.IsAllDay)
            .ThenBy(e => e.Start)
            .ToList();
    }

    public async Task<bool> DeleteEventAsync(string eventId, CancellationToken cancellationToken = default)
    {
        if (_store is null) return false;
        try
        {
            var existing = await _store.GetAppointmentAsync(eventId).AsTask(cancellationToken).ConfigureAwait(false);
            if (existing is null) return false;
            var calendar = await _store
                .GetAppointmentCalendarAsync(existing.CalendarId)
                .AsTask(cancellationToken)
                .ConfigureAwait(false);
            await calendar.DeleteAppointmentAsync(eventId).AsTask(cancellationToken).ConfigureAwait(false);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<IReadOnlyList<CalendarEventInfo>> SearchEventsAsync(
        string query,
        int daysAhead = 90,
        CancellationToken cancellationToken = default)
    {
        var trimmed = query.Trim();
        if (trimmed.Length == 0 || _store is null ||
            AuthorizationStatus != CalendarAccessStatus.FullAccess)
        {
            return Array.Empty<CalendarEventInfo>();
        }

        var start = new DateTimeOffset(DateTime.Today);
        var duration = TimeSpan.FromDays(daysAhead);
        var findOptions = new FindAppointmentsOptions { MaxCount = 2000 };
        var list = await _store
            .FindAppointmentsAsync(start, duration, findOptions)
            .AsTask(cancellationToken)
            .ConfigureAwait(false);

        return list
            .Where(a => a.Subject?.Contains(trimmed, StringComparison.CurrentCultureIgnoreCase) == true)
            .Select(MapEvent)
            .OrderBy(e => e.Start)
            .ToList();
    }

    private async Task<AppointmentStore> EnsureStoreAsync(CancellationToken cancellationToken)
    {
        if (_store is not null && AuthorizationStatus == CalendarAccessStatus.FullAccess)
            return _store;

        var granted = await RequestAccessAsync(cancellationToken).ConfigureAwait(false);
        if (!granted || _store is null)
            throw new CalendarServiceException("日历权限未授予或系统日历不可用");
        return _store;
    }

    private async Task<AppointmentCalendar> ResolveCalendarAsync(
        AppointmentStore store,
        string? calendarId,
        CancellationToken cancellationToken)
    {
        var calendars = await store
            .FindAppointmentCalendarsAsync()
            .AsTask(cancellationToken)
            .ConfigureAwait(false);

        if (!string.IsNullOrEmpty(calendarId))
        {
            var chosen = calendars.FirstOrDefault(c => c.LocalId == calendarId && c.CanCreateOrUpdateAppointments);
            if (chosen is not null) return chosen;
        }

        var writable = calendars.Where(c => c.CanCreateOrUpdateAppointments).ToList();
        var cloud = writable.FirstOrDefault(c => MapSourceKind(c) == CalendarSourceKind.Cloud);
        return cloud
               ?? writable.FirstOrDefault()
               ?? throw new CalendarServiceException("默认日历不可用");
    }

    private static Appointment BuildAllDayAppointment(string title, DateTime date, string notes)
    {
        var day = date.Date;
        var offset = TimeZoneInfo.Local.GetUtcOffset(day);
        return new Appointment
        {
            Subject = title,
            AllDay = true,
            StartTime = new DateTimeOffset(day, offset),
            Duration = TimeSpan.FromDays(1),
            Details = string.IsNullOrEmpty(notes)
                ? "提醒建议：当天 09:00（系统全天事件提醒能力有限）"
                : $"{notes}\n提醒建议：当天 09:00",
            BusyStatus = AppointmentBusyStatus.Free,
            Reminder = null
        };
    }

    private static async Task<bool> HasDuplicateAsync(
        AppointmentStore store,
        string title,
        DateTime date,
        string notes,
        string calendarLocalId,
        CancellationToken cancellationToken)
    {
        var start = new DateTimeOffset(date.Date);
        var list = await store
            .FindAppointmentsAsync(start, TimeSpan.FromDays(1))
            .AsTask(cancellationToken)
            .ConfigureAwait(false);

        return list.Any(a =>
            a.CalendarId == calendarLocalId &&
            a.Subject == title &&
            NormalizeDetails(a.Details) == NormalizeDetails(notes));
    }

    private static string NormalizeDetails(string? details)
    {
        if (string.IsNullOrEmpty(details)) return string.Empty;
        var first = details.Split('\n')[0].Trim();
        if (first.StartsWith("提醒建议", StringComparison.Ordinal)) return string.Empty;
        return first;
    }

    private static CalendarInfo MapCalendar(AppointmentCalendar calendar)
    {
        var kind = MapSourceKind(calendar);
        return new CalendarInfo
        {
            Id = calendar.LocalId,
            Title = calendar.DisplayName,
            SourceTitle = string.IsNullOrWhiteSpace(calendar.SourceDisplayName)
                ? (kind == CalendarSourceKind.Local ? "本地" : "账户")
                : calendar.SourceDisplayName,
            SourceKind = kind,
            AllowsContentModifications = calendar.CanCreateOrUpdateAppointments
        };
    }

    private static CalendarSourceKind MapSourceKind(AppointmentCalendar calendar)
    {
        var source = calendar.SourceDisplayName ?? string.Empty;
        var name = calendar.DisplayName ?? string.Empty;
        if (source.Contains("Local", StringComparison.OrdinalIgnoreCase) ||
            source.Contains("本地", StringComparison.OrdinalIgnoreCase) ||
            name.Contains("本地", StringComparison.OrdinalIgnoreCase))
        {
            return CalendarSourceKind.Local;
        }

        return CalendarSourceKind.Cloud;
    }

    private static CalendarEventInfo MapEvent(Appointment appointment)
        => new()
        {
            Id = appointment.LocalId,
            Title = appointment.Subject ?? string.Empty,
            Start = appointment.StartTime.LocalDateTime,
            End = appointment.StartTime.LocalDateTime + appointment.Duration,
            IsAllDay = appointment.AllDay,
            Notes = appointment.Details,
            CalendarId = appointment.CalendarId,
            CalendarTitle = null
        };

    private static IReadOnlyList<CalendarInfo> SortCalendars(IEnumerable<CalendarInfo> calendars)
        => calendars
            .OrderBy(c => c.SourceKind == CalendarSourceKind.Local ? 1 : 0)
            .ThenBy(c => c.SourceTitle, StringComparer.CurrentCulture)
            .ThenBy(c => c.Title, StringComparer.CurrentCulture)
            .ToList();
}
