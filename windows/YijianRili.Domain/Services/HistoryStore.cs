using YijianRili.Domain.Models;

namespace YijianRili.Domain.Services;

/// <summary>历史记录 JSON 存储（上限 20，最新在前）。</summary>
public sealed class HistoryStore
{
    public const string StorageKey = "historyEntriesData";
    public const int MaxEntries = 20;

    private readonly ISettingsStore _settings;

    public HistoryStore(ISettingsStore settings) => _settings = settings;

    public IReadOnlyList<HistoryEntry> Load()
    {
        var list = JsonSettings.Deserialize<List<HistoryEntry>>(_settings.GetString(StorageKey))
                   ?? new List<HistoryEntry>();
        // 反序列化后立即截断，防止被篡改的本地数据膨胀
        return list.Count <= MaxEntries ? list : list.Take(MaxEntries).ToList();
    }

    public void Save(IReadOnlyList<HistoryEntry> entries)
    {
        var capped = entries.Take(MaxEntries).ToList();
        _settings.SetString(StorageKey, JsonSettings.Serialize(capped));
    }

    public HistoryEntry Add(
        string title,
        DateTime baseDate,
        IReadOnlyList<DateTime> reviewDates,
        ScheduleType type,
        DateTime? creationDate = null)
    {
        var entry = new HistoryEntry
        {
            Id = Guid.NewGuid(),
            Title = title,
            BaseDate = baseDate.Date,
            ReviewDates = reviewDates.ToArray(),
            CreationDate = creationDate ?? DateTime.Now,
            Type = type
        };

        var list = Load().ToList();
        list.Insert(0, entry);
        Save(list);
        return entry;
    }

    public void Remove(Guid id)
    {
        var list = Load().Where(e => e.Id != id).ToList();
        Save(list);
    }

    public void Clear() => Save(Array.Empty<HistoryEntry>());

    public IReadOnlyList<HistoryEntry> Filter(string? query)
    {
        var all = Load();
        if (string.IsNullOrWhiteSpace(query)) return all;
        var q = query.Trim();
        return all
            .Where(e => e.Title.Contains(q, StringComparison.CurrentCultureIgnoreCase))
            .ToList();
    }
}
