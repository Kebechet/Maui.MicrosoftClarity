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
            var config = new ClarityConfig(projectId)
            {
                LogLevel = logLevel,
                ApplicationFramework = ApplicationFramework.Native
            };

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

    public partial bool SetCustomUserId(string customUserId)
    {
        try
        {
            return ClaritySDK.SetCustomUserId(customUserId);
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
            return ClaritySDK.SetCustomTagWithKey(key, value);
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
            return ClaritySDK.SetCurrentScreenName(screenName);
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
            return ClaritySDK.SetCustomSessionId(customSessionId);
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
