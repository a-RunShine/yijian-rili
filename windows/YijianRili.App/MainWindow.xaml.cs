using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Windows.System;
using YijianRili.App.Services;
using YijianRili.App.ViewModels;
using YijianRili.App.Views;
using YijianRili.Domain.Calendar;
using YijianRili.Domain.Models;

namespace YijianRili.App;

public sealed partial class MainWindow : Window
{
    private readonly MainViewModel _vm;
    private bool _suppressUiCallbacks;

    public MainWindow()
    {
        InitializeComponent();
        _vm = App.ViewModel;

        AppWindow.Resize(new Windows.Graphics.SizeInt32(400, 600));
        AppWindow.Title = "一键日历";

        _vm.WindowFloatingChanged += (_, floating) =>
        {
            if (App.MainAppWindow is not null)
                WindowTopMost.Apply(App.MainAppWindow, floating);
        };

        _vm.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName is nameof(MainViewModel.StatusText)
                or nameof(MainViewModel.CanUndo)
                or nameof(MainViewModel.CanRecreate)
                or nameof(MainViewModel.PreviewText)
                or nameof(MainViewModel.IntervalSummary)
                or nameof(MainViewModel.LocalCalendarWarningVisible)
                or nameof(MainViewModel.ShowSyncGuide)
                or nameof(MainViewModel.IsBusy))
            {
                BindFromViewModel();
            }

            if (e.PropertyName == nameof(MainViewModel.ShowSyncGuide) && _vm.ShowSyncGuide)
                _ = ShowSyncGuideAsync();
        };

        RootGrid.KeyDown += RootGrid_KeyDown;
        Activated += async (_, _) =>
        {
            _vm.ReloadCalendars();
            BindCalendars();
            await _vm.ReloadDayEventsAsync();
            BindDayEvents();
        };

        InitUiFromViewModel();
    }

    private void InitUiFromViewModel()
    {
        _suppressUiCallbacks = true;
        try
        {
            ThemeCombo.ItemsSource = new[] { "浅色", "深色", "信纸", "Claude", "跟随系统" };
            ThemeCombo.SelectedIndex = (int)_vm.CurrentTheme;

            ReviewModeRadio.IsChecked = _vm.IsReviewMode;
            SingleModeRadio.IsChecked = _vm.IsSingleMode;
            TitleBox.Text = _vm.Title;
            BaseDatePicker.Date = _vm.BaseDate;
            FloatingToggle.IsOn = _vm.WindowFloating;
            BindCalendars();
            BindFromViewModel();
            BindDayEvents();
            BindHistory();
        }
        finally
        {
            _suppressUiCallbacks = false;
        }
    }

    private void BindFromViewModel()
    {
        StatusTextBlock.Text = _vm.StatusText;
        PreviewTextBlock.Text = _vm.PreviewText;
        IntervalSummaryText.Text = _vm.IntervalSummary;
        UndoButton.IsEnabled = _vm.CanUndo;
        RecreateButton.IsEnabled = _vm.CanRecreate;
        CreateButton.IsEnabled = !_vm.IsBusy;
        LocalWarningBar.IsOpen = _vm.LocalCalendarWarningVisible;
    }

    private void BindCalendars()
    {
        _suppressUiCallbacks = true;
        try
        {
            CalendarCombo.ItemsSource = _vm.Calendars.ToList();
            if (!string.IsNullOrEmpty(_vm.SelectedCalendarId))
            {
                CalendarCombo.SelectedItem = _vm.Calendars
                    .FirstOrDefault(c => c.Id == _vm.SelectedCalendarId);
            }
        }
        finally
        {
            _suppressUiCallbacks = false;
        }
    }

    private void BindDayEvents()
    {
        DayEventsList.ItemsSource = _vm.DayEvents
            .Select(e => new
            {
                Title = e.IsAllDay
                    ? $"全天  {e.Title}"
                    : $"{e.Start:HH:mm}  {e.Title}"
            })
            .ToList();
    }

    private void BindHistory()
        => HistoryList.ItemsSource = _vm.History.ToList();

    private void RootGrid_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        var ctrl = Microsoft.UI.Input.InputKeyboardSource
            .GetKeyStateForCurrentThread(VirtualKey.Control)
            .HasFlag(Windows.UI.Core.CoreVirtualKeyStates.Down);

        if (ctrl && e.Key == VirtualKey.Enter)
        {
            e.Handled = true;
            _ = CreateAsync();
        }
    }

    private async Task CreateAsync()
    {
        await _vm.CreateAsync();
        BindHistory();
        BindDayEvents();
        _suppressUiCallbacks = true;
        try
        {
            TitleBox.Text = _vm.Title;
            BaseDatePicker.Date = _vm.BaseDate;
        }
        finally
        {
            _suppressUiCallbacks = false;
        }
        BindFromViewModel();
    }

    private async void Create_Click(object sender, RoutedEventArgs e) => await CreateAsync();

    private async void Undo_Click(object sender, RoutedEventArgs e)
    {
        await _vm.UndoAsync();
        BindDayEvents();
        BindFromViewModel();
    }

    private void Recreate_Click(object sender, RoutedEventArgs e)
    {
        _vm.Recreate();
        _suppressUiCallbacks = true;
        try
        {
            TitleBox.Text = _vm.Title;
            BaseDatePicker.Date = _vm.BaseDate;
        }
        finally
        {
            _suppressUiCallbacks = false;
        }
        BindFromViewModel();
    }

    private void PresetClassic_Click(object sender, RoutedEventArgs e)
    {
        _vm.ApplyPreset(IntervalPreset.Classic);
        BindFromViewModel();
    }

    private void PresetExam_Click(object sender, RoutedEventArgs e)
    {
        _vm.ApplyPreset(IntervalPreset.Exam);
        BindFromViewModel();
    }

    private void PresetDaily_Click(object sender, RoutedEventArgs e)
    {
        _vm.ApplyPreset(IntervalPreset.Daily);
        BindFromViewModel();
    }

    private async void Yesterday_Click(object sender, RoutedEventArgs e)
    {
        _vm.SelectedDay = DayOffset.Yesterday;
        await _vm.ReloadDayEventsAsync();
        BindDayEvents();
    }

    private async void Today_Click(object sender, RoutedEventArgs e)
    {
        _vm.SelectedDay = DayOffset.Today;
        await _vm.ReloadDayEventsAsync();
        BindDayEvents();
    }

    private async void Tomorrow_Click(object sender, RoutedEventArgs e)
    {
        _vm.SelectedDay = DayOffset.Tomorrow;
        await _vm.ReloadDayEventsAsync();
        BindDayEvents();
    }

    private void History_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not HistoryEntry entry) return;
        _vm.UseHistory(entry);
        _suppressUiCallbacks = true;
        try
        {
            TitleBox.Text = _vm.Title;
            BaseDatePicker.Date = _vm.BaseDate;
            ReviewModeRadio.IsChecked = _vm.IsReviewMode;
            SingleModeRadio.IsChecked = _vm.IsSingleMode;
        }
        finally
        {
            _suppressUiCallbacks = false;
        }
        BindFromViewModel();
    }

    private async void HelpButton_Click(object sender, RoutedEventArgs e)
    {
        _vm.OpenSyncGuide();
        await ShowSyncGuideAsync();
    }

    private async Task ShowSyncGuideAsync()
    {
        var dialog = new SyncGuideDialog { XamlRoot = RootGrid.XamlRoot };
        await dialog.ShowAsync();
        _vm.DismissSyncGuide();
    }

    private void TitleBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (_suppressUiCallbacks) return;
        _vm.Title = TitleBox.Text ?? string.Empty;
    }

    private void BaseDatePicker_DateChanged(CalendarDatePicker sender, CalendarDatePickerDateChangedEventArgs args)
    {
        if (_suppressUiCallbacks || args.NewDate is null) return;
        _vm.BaseDate = args.NewDate.Value;
        BindFromViewModel();
    }

    private void ReviewMode_Checked(object sender, RoutedEventArgs e)
    {
        if (_suppressUiCallbacks) return;
        _vm.IsReviewMode = true;
        BindFromViewModel();
    }

    private void SingleMode_Checked(object sender, RoutedEventArgs e)
    {
        if (_suppressUiCallbacks) return;
        _vm.IsSingleMode = true;
        BindFromViewModel();
    }

    private void CalendarCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressUiCallbacks) return;
        if (CalendarCombo.SelectedItem is CalendarInfo info)
            _vm.SelectedCalendarId = info.Id;
        BindFromViewModel();
    }

    private void FloatingToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (_suppressUiCallbacks) return;
        _vm.WindowFloating = FloatingToggle.IsOn;
    }

    private void ThemeCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressUiCallbacks || ThemeCombo.SelectedIndex < 0) return;
        _vm.CurrentTheme = (AppTheme)ThemeCombo.SelectedIndex;
    }
}
