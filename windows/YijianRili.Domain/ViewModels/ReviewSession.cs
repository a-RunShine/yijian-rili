using YijianRili.Domain.Calendar;
using YijianRili.Domain.Models;
using YijianRili.Domain.Services;

namespace YijianRili.Domain.ViewModels;

public enum ResultKind
{
    Success,
    Warning,
    Error
}

public enum ScheduleMode
{
    Review,
    Single
}

/// <summary>
/// 无 UI 依赖的复习创建会话编排（对齐 ReviewViewModel 核心流程）。
/// WinUI ViewModel 可薄包装本类。
/// </summary>
public sealed class ReviewSession
{
    public const string IntervalsKey = "reviewIntervalsData";
    public const string CustomPresetsKey = "customPresetsData";
    public const string SelectedCalendarKey = "selectedCalendarIdentifier";
    public const string ThemeKey = "themeName";
    public const string WindowFloatingKey = "windowFloating";
    public const string HasShownFirstRunGuideKey = "hasShownFirstRunGuide";

    private readonly ICalendarService _calendar;
    private readonly ISettingsStore _settings;
    private readonly HistoryStore _history;
    private readonly WeeklyReviewService _weekly;

    private string? _lastCreatedTitle;
    private DateTime? _lastCreatedBaseDate;

    public ReviewSession(
        ICalendarService calendar,
        ISettingsStore settings,
        HistoryStore? history = null,
        WeeklyReviewService? weekly = null)
    {
        _calendar = calendar;
        _settings = settings;
        _history = history ?? new HistoryStore(settings);
        _weekly = weekly ?? new WeeklyReviewService(settings);

        ReviewIntervals = LoadIntervals();
        CustomPresets = LoadCustomPresets();
        SelectedCalendarIdentifier = _settings.GetString(SelectedCalendarKey) ?? string.Empty;
        CurrentTheme = AppThemeExtensions.FromStorageKey(_settings.GetString(ThemeKey));
        WindowFloating = _settings.GetBool(WindowFloatingKey, defaultValue: true);
        UpdateReviewDates();
    }

    public string Title { get; set; } = string.Empty;
    public DateTime BaseDate { get; set; } = DateTime.Today;
    public ScheduleMode ScheduleMode { get; set; } = ScheduleMode.Review;
    public IReadOnlyList<DateTime> ReviewDates { get; private set; } = Array.Empty<DateTime>();
    public IReadOnlyList<int> ReviewIntervals { get; private set; }
    public IReadOnlyList<CustomPreset> CustomPresets { get; private set; }
    public string SelectedCalendarIdentifier { get; set; }
    public AppTheme CurrentTheme { get; private set; }
    public bool WindowFloating { get; private set; }
    public bool CanUndo { get; private set; }
    public bool CanRecreate { get; private set; }
    public string? ResultMessage { get; private set; }
    public ResultKind? ResultKind { get; private set; }
    public bool IsLoading { get; private set; }

    public HistoryStore History => _history;
    public WeeklyReviewService Weekly => _weekly;
    public ICalendarService Calendar => _calendar;

    public bool IsSelectedCalendarLocal
    {
        get
        {
            if (string.IsNullOrEmpty(SelectedCalendarIdentifier)) return false;
            var cal = _calendar.GetCalendar(SelectedCalendarIdentifier);
            return cal?.SourceKind == CalendarSourceKind.Local;
        }
    }

    public void UpdateReviewDates()
    {
        ReviewDates = ScheduleMode == ScheduleMode.Single
            ? new[] { BaseDate.Date }
            : ReviewEvent.CalculateReviewDates(BaseDate, ReviewIntervals);
    }

    public void SetIntervals(IReadOnlyList<int> intervals)
    {
        if (!IntervalRules.Validate(intervals))
            throw new ArgumentException("无效的复习间隔", nameof(intervals));
        ReviewIntervals = intervals.ToArray();
        _settings.SetString(IntervalsKey, JsonSettings.Serialize(ReviewIntervals));
        UpdateReviewDates();
    }

    public void ApplyPreset(IntervalPreset preset) => SetIntervals(preset.Intervals());

    public void SetTheme(AppTheme theme)
    {
        CurrentTheme = theme;
        _settings.SetString(ThemeKey, theme.StorageKey());
    }

    public void SetWindowFloating(bool floating)
    {
        WindowFloating = floating;
        _settings.SetBool(WindowFloatingKey, floating);
    }

    public void PersistSelectedCalendar()
        => _settings.SetString(SelectedCalendarKey, SelectedCalendarIdentifier ?? string.Empty);

    public bool HasShownFirstRunGuide
    {
        get => _settings.GetBool(HasShownFirstRunGuideKey);
        set => _settings.SetBool(HasShownFirstRunGuideKey, value);
    }

    public async Task CreateAsync(CancellationToken cancellationToken = default)
    {
        ResultMessage = null;
        ResultKind = null;

        var validation = TitleRules.Validate(Title);
        if (validation == TitleValidationResult.Empty)
        {
            ResultMessage = "请输入标题";
            ResultKind = ViewModels.ResultKind.Error;
            return;
        }

        if (validation == TitleValidationResult.TooLong)
        {
            ResultMessage = "标题不能超过 100 个字符";
            ResultKind = ViewModels.ResultKind.Error;
            return;
        }

        var trimmed = TitleRules.Normalize(Title);
        IsLoading = true;
        try
        {
            if (_calendar.AuthorizationStatus == CalendarAccessStatus.NotDetermined)
            {
                var granted = await _calendar.RequestAccessAsync(cancellationToken).ConfigureAwait(false);
                if (!granted)
                {
                    ResultMessage = "需要日历权限才能创建日程";
                    ResultKind = ViewModels.ResultKind.Error;
                    return;
                }
            }
            else if (_calendar.AuthorizationStatus is CalendarAccessStatus.Denied or CalendarAccessStatus.Restricted)
            {
                ResultMessage = "日历权限被拒绝，请在系统设置中开启";
                ResultKind = ViewModels.ResultKind.Error;
                return;
            }

            if (!string.IsNullOrEmpty(SelectedCalendarIdentifier) &&
                _calendar.GetCalendar(SelectedCalendarIdentifier) is null)
            {
                SelectedCalendarIdentifier = string.Empty;
                PersistSelectedCalendar();
                ResultMessage = "所选日历已失效，已回退到系统默认";
                ResultKind = ViewModels.ResultKind.Warning;
                return;
            }

            CreateEventsResult result = ScheduleMode == ScheduleMode.Review
                ? await _calendar.CreateReviewEventsAsync(
                    trimmed, BaseDate, ReviewIntervals, SelectedCalendarIdentifier, cancellationToken)
                    .ConfigureAwait(false)
                : await _calendar.CreateSingleEventAsync(
                    trimmed, BaseDate, SelectedCalendarIdentifier, cancellationToken)
                    .ConfigureAwait(false);

            if (result.Failed.Count > 0)
            {
                var failedDates = string.Join("、", result.Failed.Select(f => DateFormats.FormattedChinese(f.Date)));
                ResultMessage = $"部分日程创建失败：{failedDates}";
                ResultKind = ViewModels.ResultKind.Error;
            }
            else if (result.Duplicates.Count > 0)
            {
                var dupDates = string.Join("、", result.Duplicates.Select(DateFormats.FormattedChinese));
                ResultMessage = $"已创建，但以下日期可能重复：{dupDates}";
                ResultKind = ViewModels.ResultKind.Warning;
                OnCreateSuccess(trimmed, result.Created);
            }
            else
            {
                ResultMessage = ScheduleMode == ScheduleMode.Single
                    ? $"已创建单次日程：{DateFormats.FormattedChinese(BaseDate)}"
                    : $"已创建复习日程：{string.Join("、", result.Created.Select(DateFormats.FormattedChinese))}";
                ResultKind = ViewModels.ResultKind.Success;
                OnCreateSuccess(trimmed, result.Created);
            }
        }
        catch (Exception ex)
        {
            ResultMessage = ex.Message;
            ResultKind = ViewModels.ResultKind.Error;
        }
        finally
        {
            IsLoading = false;
        }
    }

    public async Task UndoAsync(CancellationToken cancellationToken = default)
    {
        var undo = await _calendar.UndoLastCreationAsync(cancellationToken).ConfigureAwait(false);
        var title = _lastCreatedTitle ?? string.Empty;
        if (undo.Success)
        {
            ResultMessage = string.IsNullOrEmpty(title)
                ? $"已撤销 {undo.DeletedCount} 条日程"
                : $"已撤销「{title}」共 {undo.DeletedCount} 条日程";
            ResultKind = ViewModels.ResultKind.Success;
        }
        else
        {
            ResultMessage = $"未能撤销（{undo.AlreadyDeletedCount} 条已不存在）";
            ResultKind = ViewModels.ResultKind.Warning;
        }

        CanUndo = false;
        CanRecreate = false;
    }

    public void RecreateLast()
    {
        if (_lastCreatedTitle is null || _lastCreatedBaseDate is null) return;
        Title = _lastCreatedTitle;
        BaseDate = _lastCreatedBaseDate.Value;
        UpdateReviewDates();
    }

    private void OnCreateSuccess(string trimmed, IReadOnlyList<DateTime> created)
    {
        _lastCreatedTitle = trimmed;
        _lastCreatedBaseDate = BaseDate;
        CanRecreate = true;
        CanUndo = true;

        var type = ScheduleMode == ScheduleMode.Single ? ScheduleType.Single : ScheduleType.Review;
        var entry = _history.Add(trimmed, BaseDate, created, type);
        _weekly.AppendWeeklyEntry(entry);

        Title = string.Empty;
        BaseDate = DateTime.Today;
        UpdateReviewDates();
    }

    private IReadOnlyList<int> LoadIntervals()
    {
        var raw = _settings.GetString(IntervalsKey);
        var intervals = JsonSettings.Deserialize<List<int>>(raw);
        return intervals is not null && IntervalRules.Validate(intervals)
            ? intervals
            : IntervalRules.DefaultIntervals.ToArray();
    }

    private IReadOnlyList<CustomPreset> LoadCustomPresets()
        => JsonSettings.Deserialize<List<CustomPreset>>(_settings.GetString(CustomPresetsKey))
           ?? new List<CustomPreset>();
}
