using Microsoft.Extensions.Logging;
using MicrosoftClarityiOS;

namespace Maui.MicrosoftClarity.Services;

//https://learn.microsoft.com/en-us/clarity/mobile-sdk/ios-sdk
public partial class MicrosoftClarityService
{
    public partial void Initialize(string projectId)
    {
        var logLevel = MicrosoftClarityiOS.LogLevel.None;

#if DEBUG
       logLevel = MicrosoftClarityiOS.LogLevel.Verbose;
#endif

        try
        {
            var config = new ClarityConfig(
                projectId,
                null, // Default user id
                logLevel,
                false, // Allow metered network usage
                true, // Enable web view capturing
                false, // Disable on low-end devices
                ApplicationFramework.Native
            );

            ClaritySDK.InitializeWithConfig(config);
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
            ClaritySDK.Pause();
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
            ClaritySDK.Resume();
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
            ClaritySDK.SetCustomUserId(customUserId);
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
            ClaritySDK.SetCustomTagWithKey(key, value);
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
            ClaritySDK.SetCurrentScreenNameWithName(screenName);
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
            ClaritySDK.SetCustomSessionId(customSessionId);
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
            return ClaritySDK.IsPaused;
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
            return ClaritySDK.CurrentSessionId;
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
            return ClaritySDK.CurrentSessionUrl;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(CurrentSessionUrlMethod));
            return null;
        }
    }
}
