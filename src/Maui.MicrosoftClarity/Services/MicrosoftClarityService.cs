using Microsoft.Extensions.Logging;

namespace Maui.MicrosoftClarity.Services;

public partial class MicrosoftClarityService
{
    private readonly ILogger<MicrosoftClarityService> _logger;

    public MicrosoftClarityService(ILogger<MicrosoftClarityService> logger)
    {
        _logger = logger;
    }

    public partial void Initialize(string projectId);

    public bool IsPaused => IsPausedMethod();
    public string? CurrentSessionId => CurrentSessionIdMethod();
    public string? CurrentSessionUrl => CurrentSessionUrlMethod();

    public partial void Pause();

    public partial void Resume();

    public partial bool SetCustomUserId(string customUserId);

    public partial bool SetCustomTag(string key, string value);

    public partial bool SetCurrentScreenName(string screenName);

    public partial bool SetCustomSessionId(string customSessionId);

    public partial bool SendCustomEvent(string value);

    public partial bool SetOnSessionStartedCallback(Action<string> callback);

    public partial Task<string?> StartNewSession();

    /// <summary>
    /// Manages user consent for data collection. Currently only supported on Android.
    /// </summary>
    public partial bool Consent(bool? isAdsStorageAllowed, bool? isAnalyticsStorageAllowed);
}
