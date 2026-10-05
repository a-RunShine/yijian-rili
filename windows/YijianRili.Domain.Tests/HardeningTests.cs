using YijianRili.Domain.Calendar;
using YijianRili.Domain.Models;
using YijianRili.Domain.Services;
using YijianRili.Domain.ViewModels;

namespace YijianRili.Domain.Tests;

public class HardeningTests
{
    [Fact]
    public void HistoryStore_Load_CapsEntries()
    {
        var settings = new InMemorySettingsStore();
        var oversized = Enumerable.Range(0, 50)
            .Select(i => new HistoryEntry
            {
                Id = Guid.NewGuid(),
                Title = $"t{i}",
                BaseDate = DateTime.Today,
                ReviewDates = new[] { DateTime.Today },
                CreationDate = DateTime.Now,
                Type = ScheduleType.Review
            })
            .ToList();
        settings.SetString(HistoryStore.StorageKey, JsonSettings.Serialize(oversized));

        var store = new HistoryStore(settings);
        Assert.Equal(HistoryStore.MaxEntries, store.Load().Count);
    }

    [Fact]
    public void WeeklyReviewService_LoadEntries_CapsEntries()
    {
        var settings = new InMemorySettingsStore();
        var oversized = Enumerable.Range(0, WeeklyReviewService.MaxEntries + 5)
            .Select(i => new WeeklyEntry
            {
                Id = Guid.NewGuid(),
                Title = $"w{i}",
                BaseDate = DateTime.Today,
                ScheduleType = ScheduleType.Review,
                CreationDate = DateTime.Now
            })
            .ToList();
        settings.SetString(WeeklyReviewService.WeeklyEntriesKey, JsonSettings.Serialize(oversized));
        settings.SetBool(WeeklyReviewService.HistoryMigrationKey, true);
        settings.SetBool(WeeklyReviewService.WeekendMigrationKey, true);

        var weekly = new WeeklyReviewService(settings);
        Assert.Equal(WeeklyReviewService.MaxEntries, weekly.LoadEntries().Count);
    }

    [Fact]
    public async Task InMemoryCalendar_RejectsInvalidIntervals()
    {
        var calendar = new InMemoryCalendarService();
        await Assert.ThrowsAsync<CalendarServiceException>(() =>
            calendar.CreateReviewEventsAsync("x", DateTime.Today, new[] { 30, 7, 3 }));
    }

    [Fact]
    public async Task ReviewSession_Create_UsesGenericErrorMessage()
    {
        var settings = new InMemorySettingsStore();
        var calendar = new ThrowingCalendarService();
        var session = new ReviewSession(calendar, settings);
        session.Title = "标题";
        await session.CreateAsync();
        Assert.Equal(ResultKind.Error, session.ResultKind);
        Assert.Equal("日历操作失败，请检查权限与账户后重试", session.ResultMessage);
        Assert.DoesNotContain("secret-leak", session.ResultMessage ?? string.Empty);
    }

    private sealed class ThrowingCalendarService : ICalendarService
    {
        public CalendarAccessStatus AuthorizationStatus => CalendarAccessStatus.FullAccess;
        public IReadOnlyList<CalendarInfo> AvailableCalendars => Array.Empty<CalendarInfo>();
        public bool HasCloudCalendar => false;
        public IReadOnlyList<string> LastCreatedEventIdentifiers => Array.Empty<string>();
        public Task<bool> RequestAccessAsync(CancellationToken cancellationToken = default) => Task.FromResult(true);
        public void RefreshAvailableCalendars() { }
        public CalendarInfo? GetCalendar(string identifier) => null;
        public CalendarInfo? GetDefaultCalendar() => null;

        public Task<CreateEventsResult> CreateReviewEventsAsync(
            string title, DateTime baseDate, IReadOnlyList<int> intervals,
            string? calendarId = null, CancellationToken cancellationToken = default)
            => throw new CalendarServiceException("secret-leak-internal-detail");

        public Task<CreateEventsResult> CreateSingleEventAsync(
            string title, DateTime date, string? calendarId = null,
            CancellationToken cancellationToken = default)
            => throw new CalendarServiceException("secret-leak-internal-detail");

        public Task<UndoResult> UndoLastCreationAsync(CancellationToken cancellationToken = default)
            => Task.FromResult(new UndoResult());

        public Task<IReadOnlyList<CalendarEventInfo>> FetchEventsAsync(
            DateTime date, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<CalendarEventInfo>>(Array.Empty<CalendarEventInfo>());

        public Task<bool> DeleteEventAsync(string eventId, CancellationToken cancellationToken = default)
            => Task.FromResult(false);

        public Task<IReadOnlyList<CalendarEventInfo>> SearchEventsAsync(
            string query, int daysAhead = 90, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<CalendarEventInfo>>(Array.Empty<CalendarEventInfo>());
    }
}
