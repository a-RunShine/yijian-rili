namespace YijianRili.Domain.Services;

/// <summary>规范化存储备注后再做重复检测（对齐 macOS NormalizeNotes）。</summary>
public static class NormalizeNotes
{
    /// <summary>取首行 trim；若以「提醒建议」开头则视为空备注键。</summary>
    public static string Normalize(string? details)
    {
        if (string.IsNullOrEmpty(details)) return string.Empty;
        var first = details.Split('\n')[0].Trim();
        if (first.StartsWith("提醒建议", StringComparison.Ordinal)) return string.Empty;
        return first;
    }
}
