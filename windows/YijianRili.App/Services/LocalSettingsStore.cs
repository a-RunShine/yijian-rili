using Windows.Storage;
using YijianRili.Domain.Services;

namespace YijianRili.App.Services;

/// <summary>ApplicationData.LocalSettings 实现 ISettingsStore。</summary>
public sealed class LocalSettingsStore : ISettingsStore
{
    private readonly ApplicationDataContainer _container =
        ApplicationData.Current.LocalSettings;

    public string? GetString(string key)
        => _container.Values.TryGetValue(key, out var v) ? v as string : null;

    public void SetString(string key, string value)
        => _container.Values[key] = value;

    public bool GetBool(string key, bool defaultValue = false)
    {
        if (_container.Values.TryGetValue(key, out var v) && v is bool b) return b;
        return defaultValue;
    }

    public void SetBool(string key, bool value)
        => _container.Values[key] = value;
}
