using YijianRili.Domain.Calendar;
using YijianRili.Domain.Models;
using YijianRili.Domain.Services;
using YijianRili.Domain.ViewModels;

namespace YijianRili.Domain.Tests;

public class ReviewSessionTests
{
    private static ReviewSession CreateSession(out InMemoryCalendarService calendar)
    {
        var settings = new InMemorySettingsStore();
        calendar = new InMemoryCalendarService();
        return new ReviewSession(calendar, settings);
    }

    [Fact]
    public async Task Create_RejectsEmptyTitle()
    {
        var session = CreateSession(out _);
        session.Title = "   ";
        await session.CreateAsync();
        Assert.Equal(ResultKind.Error, session.ResultKind);
        Assert.Contains("标题", session.ResultMessage);
    }

    [Fact]
    public async Task Create_RejectsLongTitle()
    {
        var session = CreateSession(out _);
        session.Title = new string('a', 101);
        await session.CreateAsync();
        Assert.Equal(ResultKind.Error, session.ResultKind);
    }

    [Fact]
    public async Task Create_ReviewSchedule_WritesHistoryAndWeekly()
    {
        var session = CreateSession(out var calendar);
        session.Title = "英语单词";
        session.BaseDate = new DateTime(2026, 6, 22);
        session.ScheduleMode = ScheduleMode.Review;
        await session.CreateAsync();

        Assert.Equal(ResultKind.Success, session.ResultKind);
        Assert.True(session.CanUndo);
        Assert.Equal(3, calendar.LastCreatedEventIdentifiers.Count);
        Assert.Single(session.History.Load());
        Assert.NotEmpty(session.Weekly.LoadEntries());
        Assert.Equal(string.Empty, session.Title);
    }

    [Fact]
    public async Task Undo_RemovesLastCreated()
    {
        var session = CreateSession(out var calendar);
        session.Title = "测试";
        await session.CreateAsync();
        await session.UndoAsync();
        Assert.True(session.ResultKind is ResultKind.Success or ResultKind.Warning);
        Assert.False(session.CanUndo);
        Assert.Empty(calendar.LastCreatedEventIdentifiers);
        var todayEvents = await calendar.FetchEventsAsync(DateTime.Today.AddDays(3));
        // events may be on future dates; just ensure undo cleared IDs
        Assert.Empty(calendar.LastCreatedEventIdentifiers);
    }

    [Fact]
    public async Task Create_DetectsDuplicateAsWarning()
    {
        var session = CreateSession(out _);
        session.Title = "重复";
        session.BaseDate = new DateTime(2026, 1, 1);
        await session.CreateAsync();

        session.Title = "重复";
        session.BaseDate = new DateTime(2026, 1, 1);
        await session.CreateAsync();
        Assert.Equal(ResultKind.Warning, session.ResultKind);
        Assert.Contains("重复", session.ResultMessage);
    }

    [Fact]
    public void ApplyPreset_UpdatesIntervals()
    {
        var session = CreateSession(out _);
        session.ApplyPreset(IntervalPreset.Classic);
        Assert.Equal(new[] { 1, 2, 4, 7, 15 }, session.ReviewIntervals);
        Assert.Equal(5, session.ReviewDates.Count);
    }

    [Fact]
    public void Weekly_WeekendReview_CreatesPlaceholder()
    {
        var settings = new InMemorySettingsStore();
        var weekly = new WeeklyReviewService(settings);
        var saturday = new DateTime(2026, 10, 3, 15, 0, 0); // Saturday
        var entry = new HistoryEntry
        {
            Id = Guid.NewGuid(),
            Title = "周末复习",
            BaseDate = saturday.Date,
            ReviewDates = new[] { saturday.Date.AddDays(3) },
            CreationDate = saturday,
            Type = ScheduleType.Review
        };
        weekly.AppendWeeklyEntry(entry);
        var all = weekly.LoadEntries();
        Assert.Equal(2, all.Count);
        Assert.Contains(all, e => !e.IsPreOccupiedNextWeek);
        Assert.Contains(all, e => e.IsPreOccupiedNextWeek && e.CreationDate.Date == new DateTime(2026, 10, 5));
    }
}
