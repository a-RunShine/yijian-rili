using Windows.ApplicationModel.Appointments;
using YijianRili.Domain.Calendar;

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
    private string? _lastError;
    private bool _looksLikeMissingPackageIdentity;

    public CalendarAccessStatus AuthorizationStatus { get; private set; } = CalendarAccessStatus.NotDetermined;

    public IReadOnlyList<CalendarInfo> AvailableCalendars => SortCalendars(_calendars);

    public bool HasCloudCalendar => AvailableCalendars.Any(c => c.SourceKind == CalendarSourceKind.Cloud);

    public IReadOnlyList<string> LastCreatedEventIdentifiers => _lastCreated.ToArray();

    public CalendarDiagnostics GetDiagnostics()
        => new()
        {
            Status = AuthorizationStatus,
            CalendarCount = _calendars.Count,
            WritableCount = _calendars.Count(c => c.AllowsContentModifications),
            LastError = _lastError,
            LooksLikeMissingPackageIdentity = _looksLikeMissingPackageIdentity
                || (AuthorizationStatus == CalendarAccessStatus.FullAccess && _calendars.Count == 0)
        };

    public async Task<bool> RequestAccessAsync(CancellationToken cancellationToken = default)
    {
        _lastError = null;
        _looksLikeMissingPackageIdentity = false;
        try
        {
            _store = await AppointmentManager
                .RequestStoreAsync(AppointmentStoreAccessType.AllCalendarsReadWrite)
                .AsTask(cancellationToken)
                .ConfigureAwait(false);

            AuthorizationStatus = _store is null
                ? CalendarAccessStatus.Denied
                : CalendarAccessStatus.FullAccess;

            if (_store is null)
            {
                _lastError = "系统拒绝打开日历存储（可能缺少 appointments 能力或未用 MSIX 安装）";
                _looksLikeMissingPackageIdentity = true;
                return false;
            }

            await RefreshAvailableCalendarsAsync(cancellationToken).ConfigureAwait(false);
            return true;
        }
        catch (UnauthorizedAccessException ex)
        {
            AuthorizationStatus = CalendarAccessStatus.Denied;
            _lastError = ex.Message;
            _looksLikeMissingPackageIdentity = true;
            return false;
        }
        catch (Exception ex)
        {
            AuthorizationStatus = CalendarAccessStatus.Denied;
            _lastError = ex.Message;
            // 未打包常见：缺少 package identity
            _looksLikeMissingPackageIdentity =
                ex.Message.Contains("package", StringComparison.OrdinalIgnoreCase) ||
                ex.Message.Contains("capability", StringComparison.OrdinalIgnoreCase) ||
                ex.HResult == unchecked((int)0x80070005);
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

        try
        {
            var winCalendars = await _store
                .FindAppointmentCalendarsAsync()
                .AsTask(cancellationToken)
                .ConfigureAwait(false);

            // 列出全部日历（含只读），避免 Google 源偶发 CanCreate=false 时列表空白
            _calendars = winCalendars.Select(MapCalendar).ToList();

            if (_calendars.Count == 0)
            {
                _lastError = "日历存储已打开，但未枚举到任何日历";
                _looksLikeMissingPackageIdentity = true;
            }
        }
        catch (Exception ex)
        {
            _calendars = new List<CalendarInfo>();
            _lastError = ex.Message;
        }
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
        var bridge = new WinRtEventStoreBridge(store, calendar);
        var outcome = await CalendarWriteOrchestrator
            .WriteReviewAsync(title, baseDate, intervals, calendar.LocalId, bridge, cancellationToken)
            .ConfigureAwait(false);
        if (outcome.CreatedEventIds.Count > 0)
        {
            _lastCreated.Clear();
            _lastCreated.AddRange(outcome.CreatedEventIds);
        }

        return outcome.Result;
    }

    public async Task<CreateEventsResult> CreateSingleEventAsync(
        string title,
        DateTime date,
        string? calendarId = null,
        CancellationToken cancellationToken = default)
    {
        var store = await EnsureStoreAsync(cancellationToken).ConfigureAwait(false);
        var calendar = await ResolveCalendarAsync(store, calendarId, cancellationToken).ConfigureAwait(false);
        var bridge = new WinRtEventStoreBridge(store, calendar);
        var outcome = await CalendarWriteOrchestrator
            .WriteSingleAsync(title, date, calendar.LocalId, bridge, cancellationToken)
            .ConfigureAwait(false);
        if (outcome.CreatedEventIds.Count > 0)
        {
            _lastCreated.Clear();
            _lastCreated.AddRange(outcome.CreatedEventIds);
        }

        return outcome.Result;
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
            throw new CalendarServiceException(GetDiagnostics().UserHint);
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
            var chosen = calendars.FirstOrDefault(c => c.LocalId == calendarId);
            if (chosen is null)
                throw new CalendarServiceException("所选日历已失效，请重新选择");
            if (!chosen.CanCreateOrUpdateAppointments)
                throw new CalendarServiceException("所选日历为只读，请选择可写入的 Google/Outlook 日历");
            return chosen;
        }

        var writable = calendars.Where(c => c.CanCreateOrUpdateAppointments).ToList();
        if (writable.Count == 0)
            throw new CalendarServiceException(GetDiagnostics().UserHint);

        var cloud = writable.FirstOrDefault(c => MapSourceKind(c) == CalendarSourceKind.Cloud);
        return cloud ?? writable[0];
    }

    private static Appointment BuildAllDayAppointment(string title, DateTime date, string notesKey)
    {
        var day = date.Date;
        var offset = TimeZoneInfo.Local.GetUtcOffset(day);
        return new Appointment
        {
            Subject = title,
            AllDay = true,
            StartTime = new DateTimeOffset(day, offset),
            Duration = TimeSpan.FromDays(1),
            Details = string.IsNullOrEmpty(notesKey)
                ? "提醒建议：当天 09:00（系统全天事件提醒能力有限）"
                : $"{notesKey}\n提醒建议：当天 09:00",
            BusyStatus = AppointmentBusyStatus.Free,
            Reminder = null
        };
    }

    /// <summary>将 WinRT AppointmentStore 适配为窄 ICalendarEventStore。</summary>
    private sealed class WinRtEventStoreBridge : ICalendarEventStore
    {
        private readonly AppointmentStore _store;
        private readonly AppointmentCalendar _calendar;

        public WinRtEventStoreBridge(AppointmentStore store, AppointmentCalendar calendar)
        {
            _store = store;
            _calendar = calendar;
        }

        public async Task<IReadOnlyList<StoredCalendarEvent>> GetEventsAsync(
            string calendarId,
            DateTime day,
            CancellationToken cancellationToken = default)
        {
            var start = new DateTimeOffset(day.Date);
            var list = await _store
                .FindAppointmentsAsync(start, TimeSpan.FromDays(1))
                .AsTask(cancellationToken)
                .ConfigureAwait(false);
            return list
                .Where(a => a.CalendarId == calendarId)
                .Select(a => new StoredCalendarEvent
                {
                    Id = a.LocalId,
                    Title = a.Subject ?? string.Empty,
                    Day = a.StartTime.LocalDateTime.Date,
                    RawNotes = a.Details ?? string.Empty
                })
                .ToList();
        }

        public async Task<string> SaveAllDayAsync(
            string calendarId,
            string title,
            DateTime day,
            string notesKey,
            CancellationToken cancellationToken = default)
        {
            if (_calendar.LocalId != calendarId)
                throw new CalendarServiceException("日历不匹配");
            var appointment = BuildAllDayAppointment(title, day, notesKey);
            await _calendar.SaveAppointmentAsync(appointment).AsTask(cancellationToken).ConfigureAwait(false);
            return appointment.LocalId ?? string.Empty;
        }
    }

    private static CalendarInfo MapCalendar(AppointmentCalendar calendar)
    {
        var kind = MapSourceKind(calendar);
        var title = calendar.DisplayName ?? "日历";
        if (!calendar.CanCreateOrUpdateAppointments)
            title += "（只读）";
        return new CalendarInfo
        {
            Id = calendar.LocalId,
            Title = title,
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
