namespace YijianRili.Domain.Services;

public enum TitleValidationResult
{
    Ok,
    Empty,
    TooLong
}

public static class TitleRules
{
    public const int MaxLength = 100;

    public static TitleValidationResult Validate(string? title)
    {
        var trimmed = (title ?? string.Empty).Trim();
        if (trimmed.Length == 0) return TitleValidationResult.Empty;
        if (trimmed.Length > MaxLength) return TitleValidationResult.TooLong;
        return TitleValidationResult.Ok;
    }

    public static string Normalize(string? title) => (title ?? string.Empty).Trim();
}
