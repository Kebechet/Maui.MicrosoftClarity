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

    public partial void SetCustomUserId(string customUserId)
    {
        try
        {
            Clarity.SetCustomUserId(customUserId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(SetCustomUserId));
        }
    }

    public partial void SetCustomTag(string key, string value)
    {
        try
        {
            Clarity.SetCustomTag(key, value);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(SetCustomTag));
        }
    }

    public partial void SetCurrentScreenName(string screenName)
    {
        try
        {
            Clarity.SetCurrentScreenName(screenName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(SetCurrentScreenName));
        }
    }

    public partial void SetCustomSessionId(string customSessionId)
    {
        try
        {
            Clarity.SetCustomSessionId(customSessionId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(SetCustomSessionId));
        }
    }

    //wrapper methods
    public bool IsPausedMethod()
    {
        try
        {
            var isPaused = Clarity.IsPaused();
            if (isPaused is null)
            {
                return false;
            }

            return (bool)isPaused;
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
