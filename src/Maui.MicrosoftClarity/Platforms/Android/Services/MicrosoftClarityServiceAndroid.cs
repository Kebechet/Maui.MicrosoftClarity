using Com.Microsoft.Clarity;
using Com.Microsoft.Clarity.Models;
using Microsoft.Extensions.Logging;

namespace Maui.MicrosoftClarity.Services;

//https://learn.microsoft.com/en-us/clarity/mobile-sdk/android-sdk
public partial class MicrosoftClarityService
{
    public partial void Initialize(string projectId)
    {
        var logLevel = Com.Microsoft.Clarity.Models.LogLevel.None;

#if DEBUG
       logLevel = Com.Microsoft.Clarity.Models.LogLevel.Verbose;
#endif

        try
        {
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
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(Initialize));
        }
    }

    public partial void Pause()
    {
        try
        {
            Clarity.Pause();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(Pause));
        }
    }

    public partial void Resume()
    {
        try
        {
            Clarity.Resume();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(Resume));
        }
    }

    public partial bool SetCustomUserId(string customUserId)
    {
        try
        {
            return (bool)Clarity.SetCustomUserId(customUserId)!;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(SetCustomUserId));
            return false;
        }
    }

    public partial bool SetCustomTag(string key, string value)
    {
        try
        {
            return Clarity.SetCustomTag(key, value)!;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(SetCustomTag));
            return false;
        }
    }

    public partial bool SetCurrentScreenName(string screenName)
    {
        try
        {
            return (bool)Clarity.SetCurrentScreenName(screenName)!;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(SetCurrentScreenName));
            return false;
        }
    }

    public partial bool SetCustomSessionId(string customSessionId)
    {
        try
        {
            return (bool)Clarity.SetCustomSessionId(customSessionId)!;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(SetCustomSessionId));
            return false;
        }
    }

    //wrapper methods
    public bool IsPausedMethod()
    {
        try
        {
            return (bool)Clarity.IsPaused()!;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(IsPausedMethod));
            return false;
        }
    }
    public string? CurrentSessionIdMethod()
    {
        try
        {
            return Clarity.CurrentSessionId;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(CurrentSessionIdMethod));
            return null;
        }
    }
    public string? CurrentSessionUrlMethod()
    {
        try
        {
            return Clarity.CurrentSessionUrl;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(CurrentSessionUrlMethod));
            return null;
        }
    }
}
