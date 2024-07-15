using Com.Microsoft.Clarity;
using Com.Microsoft.Clarity.Models;

namespace Maui.MicrosoftClarity.Services;

//https://learn.microsoft.com/en-us/clarity/mobile-sdk/android-sdk
public partial class MicrosoftClarityService
{
    public partial void Initialize(string projectId)
    {
        var logLevel = LogLevel.None;

#if DEBUG
       logLevel = LogLevel.Verbose;
#endif

        var config = new ClarityConfig(
            projectId,
            null, // Default user id
            logLevel!,
            false, // Disallow metered network usage
            true, // Enable web view capturing
            ["*"], // Allowed domains
            ApplicationFramework.Native!,
            [], // Allowed activities
            [], // Disallowed activities (ignore activities)
            false, // Disable on low-end devices
            null //maximumDailyNetworkUsageInMB
        );

        Clarity.Initialize(Platform.CurrentActivity, config);
    }

    public partial void Pause()
    {
        Clarity.Pause();
    }

    public partial void Resume()
    {
        Clarity.Resume();
    }

    public partial void SetCustomUserId(string customUserId)
    {
        Clarity.SetCustomUserId(customUserId);
    }

    public partial void SetCustomTag(string key, string value)
    {
        Clarity.SetCustomTag(key, value);
    }

    public partial void SetCurrentScreenName(string screenName)
    {
        Clarity.SetCurrentScreenName(screenName);
    }

    public partial void SetCustomSessionId(string customSessionId)
    {
        Clarity.SetCustomSessionId(customSessionId);
    }

    //wrapper methods
    public bool IsPausedMethod()
    {
        var isPaused = Clarity.IsPaused();
        if (isPaused is null)
        {
            return false;
        }

        return (bool)isPaused;
    }
    public string? CurrentSessionIdMethod()
    {
        return Clarity.CurrentSessionId;
    }
    public string? CurrentSessionUrlMethod()
    {
        return Clarity.CurrentSessionUrl;
    }
}
