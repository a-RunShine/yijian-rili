namespace YijianRili.Domain.Calendar;

/// <summary>
/// 日历服务抽象，形状对齐 macOS CalendarManager。
/// Windows 实现：WinRT Appointments；测试：InMemoryCalendarService。
/// </summary>
public interface ICalendarService
{
    CalendarAccessStatus AuthorizationStatus { get; }

    IReadOnlyList<CalendarInfo> AvailableCalendars { get; }

    bool HasCloudCalendar { get; }

    IReadOnlyList<string> LastCreatedEventIdentifiers { get; }

    Task<bool> RequestAccessAsync(CancellationToken cancellationToken = default);

    void RefreshAvailableCalendars();

    CalendarInfo? GetCalendar(string identifier);

    CalendarInfo? GetDefaultCalendar();

    Task<CreateEventsResult> CreateReviewEventsAsync(
        string title,
        DateTime baseDate,
        IReadOnlyList<int> intervals,
        string? calendarId = null,
        CancellationToken cancellationToken = default);

    Task<CreateEventsResult> CreateSingleEventAsync(
        string title,
        DateTime date,
        string? calendarId = null,
        CancellationToken cancellationToken = default);

    Task<UndoResult> UndoLastCreationAsync(CancellationToken cancellationToken = default);

    Task<IReadOnlyList<CalendarEventInfo>> FetchEventsAsync(
        DateTime date,
        CancellationToken cancellationToken = default);

    Task<bool> DeleteEventAsync(string eventId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<CalendarEventInfo>> SearchEventsAsync(
        string query,
        int daysAhead = 90,
        CancellationToken cancellationToken = default);

    /// <summary>供 UI 展示权限/空日历诊断。</summary>
    CalendarDiagnostics GetDiagnostics();
}
