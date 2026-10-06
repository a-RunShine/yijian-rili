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

/// <summary>用户可见的日历诊断信息（权限/空列表/打包问题）。</summary>
public sealed class CalendarDiagnostics
{
    public CalendarAccessStatus Status { get; init; }
    public int CalendarCount { get; init; }
    public int WritableCount { get; init; }
    public string? LastError { get; init; }
    public bool LooksLikeMissingPackageIdentity { get; init; }

    public string UserHint
    {
        get
        {
            if (Status is CalendarAccessStatus.Denied or CalendarAccessStatus.Restricted)
                return "日历权限未授予。请在系统弹窗中允许，或到「设置 → 隐私和安全性 → 日历」开启本应用权限。";

            if (CalendarCount == 0 || WritableCount == 0)
            {
                return "未找到可写日历。请确认：\n"
                       + "1) 用 MSIX 安装本应用（不要直接运行未打包的 exe）\n"
                       + "2) 在「设置 → 账户 → 电子邮件和账户」添加 Google/Outlook，并开启日历同步\n"
                       + "3) 打开系统「日历」App，确认能看到该账户下的日历\n"
                       + "（仅在浏览器登录 Gmail 不够）";
            }

            return LastError ?? string.Empty;
        }
    }
}
