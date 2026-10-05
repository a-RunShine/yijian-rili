using Microsoft.UI.Xaml;
using YijianRili.App.Services;
using YijianRili.App.ViewModels;
using YijianRili.Calendar;
using YijianRili.Domain.Calendar;

namespace YijianRili.App;

public partial class App : Application
{
    private Window? _window;

    public App()
    {
        InitializeComponent();
    }

    public static MainViewModel ViewModel { get; private set; } = null!;

    public static Window? MainAppWindow { get; private set; }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        ICalendarService calendar = new WinRtCalendarService();
        var settings = new LocalSettingsStore();
        ViewModel = new MainViewModel(calendar, settings);

        _window = new MainWindow();
        MainAppWindow = _window;
        _window.Activate();

        WindowTopMost.Apply(_window, ViewModel.Session.WindowFloating);
        _ = ViewModel.InitializeAsync();
    }
}
