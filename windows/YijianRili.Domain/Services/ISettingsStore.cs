namespace YijianRili.Domain.Services;

/// <summary>键值持久化抽象（macOS UserDefaults / Windows ApplicationData）。</summary>
public interface ISettingsStore
{
    string? GetString(string key);
    void SetString(string key, string value);
    bool GetBool(string key, bool defaultValue = false);
    void SetBool(string key, bool value);
}

/// <summary>进程内字典实现，供单测与无 UI 场景使用。</summary>
public sealed class InMemorySettingsStore : ISettingsStore
{
    private readonly Dictionary<string, string> _strings = new(StringComparer.Ordinal);
    private readonly Dictionary<string, bool> _bools = new(StringComparer.Ordinal);

    public string? GetString(string key)
        => _strings.TryGetValue(key, out var v) ? v : null;

    public void SetString(string key, string value) => _strings[key] = value;

    public bool GetBool(string key, bool defaultValue = false)
        => _bools.TryGetValue(key, out var v) ? v : defaultValue;

    public void SetBool(string key, bool value) => _bools[key] = value;
}
