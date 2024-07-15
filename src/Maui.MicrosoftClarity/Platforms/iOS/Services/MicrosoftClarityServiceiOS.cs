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

    public partial void SetCustomUserId(string customUserId)
    {
    }

    public partial void SetCustomTag(string key, string value)
    {
    }

    public partial void SetCurrentScreenName(string screenName)
    {
    }

    public partial void SetCustomSessionId(string customSessionId)
    {
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
