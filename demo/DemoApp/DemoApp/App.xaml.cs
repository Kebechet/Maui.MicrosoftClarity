using Maui.MicrosoftClarity.Services;

namespace DemoApp;

public partial class App : Application
{
    private readonly MicrosoftClarityService _microsoftClarityService;

    public App(MicrosoftClarityService microsoftClarityService)
    {
        InitializeComponent();
        _microsoftClarityService = microsoftClarityService;

        MainPage = new MainPage();
    }

    protected override void OnStart()
    {
        var microsoftClarityProjectId = "";
        if (string.IsNullOrEmpty(microsoftClarityProjectId))
        {
            throw new InvalidOperationException("Microsoft Clarity Project Id is not set. Please set it in App.xaml.cs.");
        }

        _microsoftClarityService.Initialize(microsoftClarityProjectId);
        _microsoftClarityService.Consent(isAdsStorageAllowed: true, isAnalyticsStorageAllowed: true);

        base.OnStart();
    }
}
