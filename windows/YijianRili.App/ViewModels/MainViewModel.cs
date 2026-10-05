using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using YijianRili.Domain.Calendar;
using YijianRili.Domain.Models;
using YijianRili.Domain.Services;
using YijianRili.Domain.ViewModels;

namespace YijianRili.App.ViewModels;

public sealed class MainViewModel : INotifyPropertyChanged
{
    private readonly ICalendarService _calendar;
    private string _statusText = "就绪";
    private bool _isBusy;
    private bool _showSyncGuide;
    private CalendarEventInfo? _selectedDayEvent;
    private string _previewText = string.Empty;
    private DayOffset _dayOffset = DayOffset.Today;

    public MainViewModel(ICalendarService calendar, ISettingsStore settings)
    {
        _calendar = calendar;
        Session = new ReviewSession(calendar, settings);
        RefreshPreview();
    }

    public ReviewSession Session { get; }

    public ObservableCollection<CalendarInfo> Calendars { get; } = new();
    public ObservableCollection<CalendarEventInfo> DayEvents { get; } = new();
    public ObservableCollection<HistoryEntry> History { get; } = new();
    public ObservableCollection<string> PreviewLines { get; } = new();

    public string Title
    {
        get => Session.Title;
        set
        {
            if (Session.Title == value) return;
            Session.Title = value;
            OnPropertyChanged();
        }
    }

    public DateTimeOffset BaseDate
    {
        get => new(Session.BaseDate);
        set
        {
            Session.BaseDate = value.Date;
            Session.UpdateReviewDates();
            RefreshPreview();
            OnPropertyChanged();
        }
    }

    public bool IsReviewMode
    {
        get => Session.ScheduleMode == ScheduleMode.Review;
        set
        {
            Session.ScheduleMode = value ? ScheduleMode.Review : ScheduleMode.Single;
            Session.UpdateReviewDates();
            RefreshPreview();
            OnPropertyChanged();
            OnPropertyChanged(nameof(IsSingleMode));
        }
    }

    public bool IsSingleMode
    {
        get => Session.ScheduleMode == ScheduleMode.Single;
        set => IsReviewMode = !value;
    }

    public bool WindowFloating
    {
        get => Session.WindowFloating;
        set
        {
            Session.SetWindowFloating(value);
            OnPropertyChanged();
            WindowFloatingChanged?.Invoke(this, value);
        }
    }

    public event EventHandler<bool>? WindowFloatingChanged;

    public string SelectedCalendarId
    {
        get => Session.SelectedCalendarIdentifier;
        set
        {
            Session.SelectedCalendarIdentifier = value ?? string.Empty;
            Session.PersistSelectedCalendar();
            OnPropertyChanged();
            OnPropertyChanged(nameof(LocalCalendarWarningVisible));
        }
    }

    public bool LocalCalendarWarningVisible => Session.IsSelectedCalendarLocal;

    public string StatusText
    {
        get => _statusText;
        private set
        {
            _statusText = value;
            OnPropertyChanged();
        }
    }

    public bool IsBusy
    {
        get => _isBusy;
        private set
        {
            _isBusy = value;
            OnPropertyChanged();
        }
    }

    public bool CanUndo => Session.CanUndo;
    public bool CanRecreate => Session.CanRecreate;

    public bool ShowSyncGuide
    {
        get => _showSyncGuide;
        set
        {
            _showSyncGuide = value;
            OnPropertyChanged();
        }
    }

    public string PreviewText
    {
        get => _previewText;
        private set
        {
            _previewText = value;
            OnPropertyChanged();
        }
    }

    public DayOffset SelectedDay
    {
        get => _dayOffset;
        set
        {
            _dayOffset = value;
            OnPropertyChanged();
            _ = ReloadDayEventsAsync();
        }
    }

    public CalendarEventInfo? SelectedDayEvent
    {
        get => _selectedDayEvent;
        set
        {
            _selectedDayEvent = value;
            OnPropertyChanged();
        }
    }

    public IReadOnlyList<IntervalPreset> Presets { get; } =
        Enum.GetValues<IntervalPreset>().ToArray();

    public IReadOnlyList<AppTheme> Themes { get; } =
        Enum.GetValues<AppTheme>().ToArray();

    public AppTheme CurrentTheme
    {
        get => Session.CurrentTheme;
        set
        {
            Session.SetTheme(value);
            OnPropertyChanged();
        }
    }

    public async Task InitializeAsync()
    {
        await _calendar.RequestAccessAsync().ConfigureAwait(true);
        if (_calendar is YijianRili.Calendar.WinRtCalendarService winRt)
            await winRt.RefreshAvailableCalendarsAsync().ConfigureAwait(true);
        else
            _calendar.RefreshAvailableCalendars();

        ReloadCalendars();
        ReloadHistory();
        await ReloadDayEventsAsync().ConfigureAwait(true);

        if (!Session.HasShownFirstRunGuide &&
            _calendar.AuthorizationStatus == CalendarAccessStatus.FullAccess &&
            !_calendar.HasCloudCalendar)
        {
            await Task.Delay(TimeSpan.FromSeconds(3)).ConfigureAwait(true);
            if (!Session.HasShownFirstRunGuide && !_calendar.HasCloudCalendar)
                ShowSyncGuide = true;
        }
    }

    public void ReloadCalendars()
    {
        Calendars.Clear();
        foreach (var c in _calendar.AvailableCalendars)
            Calendars.Add(c);
        OnPropertyChanged(nameof(LocalCalendarWarningVisible));
    }

    public void ReloadHistory()
    {
        History.Clear();
        foreach (var h in Session.History.Load())
            History.Add(h);
    }

    public async Task ReloadDayEventsAsync()
    {
        var date = DateTime.Today.AddDays((int)SelectedDay);
        var events = await _calendar.FetchEventsAsync(date).ConfigureAwait(true);
        DayEvents.Clear();
        foreach (var e in events) DayEvents.Add(e);
    }

    public void ApplyPreset(IntervalPreset preset)
    {
        Session.ApplyPreset(preset);
        RefreshPreview();
        OnPropertyChanged(nameof(IntervalSummary));
    }

    public string IntervalSummary =>
        "间隔：" + string.Join("/", Session.ReviewIntervals) + " 天";

    public async Task CreateAsync()
    {
        IsBusy = true;
        try
        {
            await Session.CreateAsync().ConfigureAwait(true);
            StatusText = Session.ResultMessage ?? "完成";
            ReloadHistory();
            await ReloadDayEventsAsync().ConfigureAwait(true);
            OnPropertyChanged(nameof(CanUndo));
            OnPropertyChanged(nameof(CanRecreate));
            OnPropertyChanged(nameof(Title));
            OnPropertyChanged(nameof(BaseDate));
            RefreshPreview();
        }
        finally
        {
            IsBusy = false;
        }
    }

    public async Task UndoAsync()
    {
        IsBusy = true;
        try
        {
            await Session.UndoAsync().ConfigureAwait(true);
            StatusText = Session.ResultMessage ?? "已撤销";
            await ReloadDayEventsAsync().ConfigureAwait(true);
            OnPropertyChanged(nameof(CanUndo));
            OnPropertyChanged(nameof(CanRecreate));
        }
        finally
        {
            IsBusy = false;
        }
    }

    public void Recreate()
    {
        Session.RecreateLast();
        OnPropertyChanged(nameof(Title));
        OnPropertyChanged(nameof(BaseDate));
        RefreshPreview();
    }

    public void DismissSyncGuide()
    {
        ShowSyncGuide = false;
        Session.HasShownFirstRunGuide = true;
    }

    public void OpenSyncGuide() => ShowSyncGuide = true;

    public void UseHistory(HistoryEntry entry)
    {
        Title = entry.Title;
        BaseDate = new DateTimeOffset(entry.BaseDate);
        IsReviewMode = entry.Type == ScheduleType.Review;
    }

    private void RefreshPreview()
    {
        PreviewLines.Clear();
        if (Session.ScheduleMode == ScheduleMode.Single)
        {
            PreviewLines.Add($"单次：{DateFormats.FormattedChinese(Session.BaseDate)}");
        }
        else
        {
            for (var i = 0; i < Session.ReviewDates.Count; i++)
            {
                PreviewLines.Add(
                    $"{ReviewNoteText.ForIndex(i)}  {DateFormats.FormattedChinese(Session.ReviewDates[i])}");
            }
        }

        PreviewText = string.Join(Environment.NewLine, PreviewLines);
        OnPropertyChanged(nameof(IntervalSummary));
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnPropertyChanged([CallerMemberName] string? name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

public enum DayOffset
{
    Yesterday = -1,
    Today = 0,
    Tomorrow = 1
}
