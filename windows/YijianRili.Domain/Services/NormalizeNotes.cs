namespace YijianRili.Domain.Services;

public static class NormalizeNotes
{
    public static string Normalize(string? details)
    {
        if (string.IsNullOrEmpty(details)) return string.Empty;
        var first = details.Split('\n')[0].Trim();
        if (first.StartsWith("提醒建议", StringComparison.Ordinal)) return string.Empty;
        return first;
    }
}
