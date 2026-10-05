namespace YijianRili.Domain.Calendar;

public enum CalendarAccessStatus
{
    NotDetermined,
    Denied,
    Restricted,
    FullAccess
}

public enum CalendarSourceKind
{
    Local,
    Cloud,
    Unknown
}

public sealed class CalendarInfo
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public required string SourceTitle { get; init; }
    public CalendarSourceKind SourceKind { get; init; }
    public bool AllowsContentModifications { get; init; } = true;
    public string? ColorHex { get; init; }

    public string DisplayName => $"{SourceTitle} → {Title}";
}

public sealed class CalendarEventInfo
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public DateTime Start { get; init; }
    public DateTime End { get; init; }
    public bool IsAllDay { get; init; }
    public string? Notes { get; init; }
    public string? CalendarId { get; init; }
    public string? CalendarTitle { get; init; }
    public string? ColorHex { get; init; }
}

public sealed class CreateEventsResult
{
    public List<DateTime> Created { get; } = new();
    public List<DateTime> Duplicates { get; } = new();
    public List<(DateTime Date, string Error)> Failed { get; } = new();
}

public sealed class UndoResult
{
    public bool Success { get; init; }
    public int DeletedCount { get; init; }
    public int AlreadyDeletedCount { get; init; }
}

public sealed class CalendarServiceException : Exception
{
    public CalendarServiceException(string message) : base(message) { }
    public CalendarServiceException(string message, Exception inner) : base(message, inner) { }
}
