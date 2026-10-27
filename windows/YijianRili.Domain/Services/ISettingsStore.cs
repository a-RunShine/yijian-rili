namespace YijianRili.Domain.Services;

public interface ISettingsStore
{
    string? GetString(string key);
    void SetString(string key, string value);
    bool GetBool(string key, bool defaultValue = false);
    void SetBool(string key, bool value);
}

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
