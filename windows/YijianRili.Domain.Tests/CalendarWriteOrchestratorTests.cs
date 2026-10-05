using YijianRili.Domain.Calendar;
using YijianRili.Domain.Services;

namespace YijianRili.Domain.Tests;

public class CalendarWriteOrchestratorTests
{
    [Fact]
    public void NormalizeNotes_StripsReminderLine()
    {
        Assert.Equal(string.Empty, NormalizeNotes.Normalize(null));
        Assert.Equal("第1次复习", NormalizeNotes.Normalize("第1次复习\n提醒建议：当天 09:00"));
        Assert.Equal(string.Empty, NormalizeNotes.Normalize("提醒建议：当天 09:00"));
    }

    [Fact]
    public async Task WriteReview_DetectsDuplicates_ViaNormalizedNotes()
    {
        var store = new FakeStore();
        var baseDate = new DateTime(2026, 1, 31);
        var first = await CalendarWriteOrchestrator.WriteReviewAsync(
            "T", baseDate, new[] { 3, 7, 30 }, "cal", store);
        Assert.Equal(3, first.Result.Created.Count);
        Assert.Empty(first.Result.Duplicates);

        var second = await CalendarWriteOrchestrator.WriteReviewAsync(
            "T", baseDate, new[] { 3, 7, 30 }, "cal", store);
        Assert.Equal(3, second.Result.Duplicates.Count);
        Assert.Equal(3, second.Result.Created.Count);
    }

    [Fact]
    public async Task WriteReview_RejectsInvalidIntervals()
    {
        var store = new FakeStore();
        await Assert.ThrowsAsync<CalendarServiceException>(() =>
            CalendarWriteOrchestrator.WriteReviewAsync(
                "T", DateTime.Today, new[] { 30, 7, 3 }, "cal", store));
    }

    private sealed class FakeStore : ICalendarEventStore
    {
        private readonly List<StoredCalendarEvent> _items = new();
        private int _seq;

        public Task<IReadOnlyList<StoredCalendarEvent>> GetEventsAsync(
            string calendarId,
            DateTime day,
            CancellationToken cancellationToken = default)
        {
            var list = _items.Where(e => e.Day.Date == day.Date).ToList();
            return Task.FromResult<IReadOnlyList<StoredCalendarEvent>>(list);
        }

        public Task<string> SaveAllDayAsync(
            string calendarId,
            string title,
            DateTime day,
            string notesKey,
            CancellationToken cancellationToken = default)
        {
            var id = $"fake-{++_seq}";
            var raw = string.IsNullOrEmpty(notesKey)
                ? "提醒建议：当天 09:00"
                : $"{notesKey}\n提醒建议：当天 09:00";
            _items.Add(new StoredCalendarEvent
            {
                Id = id,
                Title = title,
                Day = day.Date,
                RawNotes = raw
            });
            return Task.FromResult(id);
        }
    }
}
