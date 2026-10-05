using YijianRili.Domain.Models;

namespace YijianRili.Domain.Services;

/// <summary>
/// 周末总结领域服务（对齐 WeeklyReviewViewModel 持久化与周规则，不含 UI）。
/// </summary>
public sealed class WeeklyReviewService
{
    public const string WeeklyEntriesKey = "weeklyEntriesData";
    public const string WeeklyReviewStateKey = "weeklyReviewStateData";
    public const string WeeklyNotesKey = "weeklyNotesData";
    public const string HistoryMigrationKey = "weeklyEntriesHistoryMigrationDone";
    public const string WeekendMigrationKey = "weeklyEntriesWeekendMigrationDone";

    private readonly ISettingsStore _settings;

    public WeeklyReviewService(ISettingsStore settings)
    {
        _settings = settings;
        CurrentWeekStart = WeekCalculator.WeekStart(DateTime.Today);
        PerformHistoryMigrationIfNeeded();
        PerformWeekendMigrationIfNeeded();
        NoteDraft = CurrentWeekNote;
    }

    public DateTime CurrentWeekStart { get; private set; }

    public string NoteDraft { get; private set; } = string.Empty;

    public DateTime CurrentWeekEnd => WeekCalculator.WeekEnd(CurrentWeekStart);

    public string CurrentWeekKey => WeekCalculator.WeekKey(CurrentWeekStart);

    public IReadOnlyList<WeeklyEntry> LoadEntries()
        => JsonSettings.Deserialize<List<WeeklyEntry>>(_settings.GetString(WeeklyEntriesKey))
           ?? new List<WeeklyEntry>();

    public IReadOnlySet<Guid> ReviewedIds
    {
        get
        {
            var ids = JsonSettings.Deserialize<List<Guid>>(_settings.GetString(WeeklyReviewStateKey))
                      ?? new List<Guid>();
            return ids.ToHashSet();
        }
    }

    public string CurrentWeekNote
    {
        get
        {
            var notes = DecodeNotes();
            return notes.ByWeek.TryGetValue(CurrentWeekKey, out var n) ? n : string.Empty;
        }
    }

    public IReadOnlyList<WeeklyEntry> EntriesInCurrentWeek
    {
        get
        {
            var start = CurrentWeekStart;
            var end = CurrentWeekEnd;
            return LoadEntries()
                .Where(e => e.CreationDate >= start && e.CreationDate <= end)
                .OrderByDescending(e => e.CreationDate)
                .ToList();
        }
    }

    public IReadOnlyList<WeeklyEntry> RealEntriesInCurrentWeek
        => EntriesInCurrentWeek.Where(e => !e.IsPreOccupiedNextWeek).ToList();

    public int ReviewedCount
    {
        get
        {
            var reviewed = ReviewedIds;
            return RealEntriesInCurrentWeek.Count(e => reviewed.Contains(e.Id));
        }
    }

    public int TotalCount => RealEntriesInCurrentWeek.Count;

    public bool CanGoToNextWeek
    {
        get
        {
            var thisMonday = WeekCalculator.WeekStart(DateTime.Today);
            return CurrentWeekStart < thisMonday;
        }
    }

    public void GoToPreviousWeek()
    {
        CommitNoteDraft();
        CurrentWeekStart = WeekCalculator.AddingWeeks(-1, CurrentWeekStart);
        NoteDraft = CurrentWeekNote;
    }

    public void GoToNextWeek()
    {
        if (!CanGoToNextWeek) return;
        CommitNoteDraft();
        CurrentWeekStart = WeekCalculator.AddingWeeks(1, CurrentWeekStart);
        NoteDraft = CurrentWeekNote;
    }

    public void JumpToCurrentWeek()
    {
        CommitNoteDraft();
        CurrentWeekStart = WeekCalculator.WeekStart(DateTime.Today);
        NoteDraft = CurrentWeekNote;
    }

    public void CommitNoteDraft()
    {
        var notes = DecodeNotes();
        if (notes.ByWeek.TryGetValue(CurrentWeekKey, out var existing) && existing == NoteDraft)
            return;
        notes.ByWeek[CurrentWeekKey] = NoteDraft;
        WriteNotes(notes);
    }

    public void UpdateNote(string text)
    {
        NoteDraft = text;
        var notes = DecodeNotes();
        notes.ByWeek[CurrentWeekKey] = text;
        WriteNotes(notes);
    }

    public bool IsReviewed(Guid id) => ReviewedIds.Contains(id);

    public void ToggleReviewed(Guid id)
    {
        var set = ReviewedIds.ToHashSet();
        if (!set.Add(id)) set.Remove(id);
        _settings.SetString(WeeklyReviewStateKey, JsonSettings.Serialize(set.ToList()));
    }

    /// <summary>追加 weekly entry；周末复习计划写入下一周预占位副本。</summary>
    public void AppendWeeklyEntry(HistoryEntry historyEntry)
    {
        var entries = LoadEntries().ToList();
        entries.RemoveAll(e => e.Id == historyEntry.Id);

        entries.Add(new WeeklyEntry
        {
            Id = historyEntry.Id,
            Title = historyEntry.Title,
            BaseDate = historyEntry.BaseDate,
            ScheduleType = historyEntry.Type,
            CreationDate = historyEntry.CreationDate,
            IsPreOccupiedNextWeek = false
        });

        if (historyEntry.Type == ScheduleType.Review &&
            WeekCalculator.IsWeekend(historyEntry.CreationDate))
        {
            var nextMonday = WeekCalculator.NextWeekMonday(historyEntry.CreationDate);
            if (!entries.Any(e => e.Id == historyEntry.Id && e.CreationDate == nextMonday))
            {
                entries.Add(new WeeklyEntry
                {
                    Id = historyEntry.Id,
                    Title = historyEntry.Title,
                    BaseDate = historyEntry.BaseDate,
                    ScheduleType = historyEntry.Type,
                    CreationDate = nextMonday,
                    IsPreOccupiedNextWeek = true
                });
            }
        }

        PersistEntries(entries);
    }

    public void PersistEntries(IReadOnlyList<WeeklyEntry> entries)
        => _settings.SetString(WeeklyEntriesKey, JsonSettings.Serialize(entries));

    public void PerformHistoryMigrationIfNeeded()
    {
        if (_settings.GetBool(HistoryMigrationKey)) return;

        var legacyRaw = _settings.GetString(HistoryStore.StorageKey) ?? string.Empty;
        var legacy = JsonSettings.Deserialize<List<HistoryEntry>>(legacyRaw) ?? new List<HistoryEntry>();
        var existing = LoadEntries().ToList();
        var existingIds = existing.Select(e => e.Id).ToHashSet();
        var toMigrate = legacy.Where(h => !existingIds.Contains(h.Id)).ToList();

        if (toMigrate.Count > 0)
        {
            existing.AddRange(toMigrate.Select(h => new WeeklyEntry
            {
                Id = h.Id,
                Title = h.Title,
                BaseDate = h.BaseDate,
                ScheduleType = h.Type,
                CreationDate = h.CreationDate,
                IsPreOccupiedNextWeek = false
            }));
            PersistEntries(existing);
        }

        _settings.SetBool(HistoryMigrationKey, true);
    }

    public void PerformWeekendMigrationIfNeeded()
    {
        if (_settings.GetBool(WeekendMigrationKey)) return;

        var entries = LoadEntries().ToList();
        var added = false;
        var snapshot = entries.ToList();

        foreach (var entry in snapshot)
        {
            if (entry.ScheduleType != ScheduleType.Review) continue;
            if (entry.IsPreOccupiedNextWeek) continue;
            if (!WeekCalculator.IsWeekend(entry.CreationDate)) continue;

            var nextMonday = WeekCalculator.NextWeekMonday(entry.CreationDate);
            var hasPlaceholder = entries.Any(e =>
                e.Id == entry.Id &&
                e.IsPreOccupiedNextWeek &&
                e.CreationDate.Date == nextMonday.Date);

            if (hasPlaceholder) continue;

            entries.Add(new WeeklyEntry
            {
                Id = entry.Id,
                Title = entry.Title,
                BaseDate = entry.BaseDate,
                ScheduleType = entry.ScheduleType,
                CreationDate = nextMonday,
                IsPreOccupiedNextWeek = true
            });
            added = true;
        }

        if (added) PersistEntries(entries);
        _settings.SetBool(WeekendMigrationKey, true);
    }

    private WeeklyNotes DecodeNotes()
        => JsonSettings.Deserialize<WeeklyNotes>(_settings.GetString(WeeklyNotesKey))
           ?? new WeeklyNotes();

    private void WriteNotes(WeeklyNotes notes)
        => _settings.SetString(WeeklyNotesKey, JsonSettings.Serialize(notes));
}
