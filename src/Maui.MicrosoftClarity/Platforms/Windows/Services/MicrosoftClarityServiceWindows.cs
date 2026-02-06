namespace Maui.MicrosoftClarity.Services;

public partial class MicrosoftClarityService
{
    public partial void Initialize(string projectId)
    {
    }

    public partial void Pause()
    {
    }

    public partial void Resume()
    {
    }

    public partial bool SetCustomUserId(string customUserId)
    {
        return true;
    }

    public partial bool SetCustomTag(string key, string value)
    {
        return true;
    }

    public partial bool SetCurrentScreenName(string screenName)
    {
        return true;
    }

    public partial bool SetCustomSessionId(string customSessionId)
    {
        return true;
    }

    public partial bool SendCustomEvent(string value)
    {
        return true;
    }

    public partial bool SetOnSessionStartedCallback(Action<string> callback)
    {
        return true;
    }

    public partial Task<string?> StartNewSession()
    {
        return Task.FromResult<string?>(null);
    }

    public partial bool Consent(bool? isAdsStorageAllowed, bool? isAnalyticsStorageAllowed)
    {
        return false;
    }

    //wrapper methods
    public bool IsPausedMethod()
    {
        return true;
    }
    public string? CurrentSessionIdMethod()
    {
        return null;
    }
    public string? CurrentSessionUrlMethod()
    {
        return null;
    }
}
