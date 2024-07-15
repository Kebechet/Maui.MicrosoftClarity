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
