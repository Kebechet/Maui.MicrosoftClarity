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
            var config = new ClarityConfig(projectId)
            {
                UserId = null,
                LogLevel = logLevel!,
                ApplicationFramework = ApplicationFramework.Native!,
            };

            ClaritySdk.Initialize(Platform.CurrentActivity, config);
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
            ClaritySdk.Pause();
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
            ClaritySdk.Resume();
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
            return (bool)ClaritySdk.SetCustomUserId(customUserId)!;
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
            return ClaritySdk.SetCustomTag(key, value)!;
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
            return (bool)ClaritySdk.SetCurrentScreenName(screenName)!;
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
            return (bool)ClaritySdk.SetCustomSessionId(customSessionId)!;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(SetCustomSessionId));
            return false;
        }
    }

    //public partial void StartNewSession()
    //{
    //    try
    //    {
    //        ClaritySdk.StartNewSession();
    //    }
    //    catch (Exception ex)
    //    {
    //        _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(StartNewSession));
    //    }
    //}

    //wrapper methods
    public bool IsPausedMethod()
    {
        try
        {
            return (bool)ClaritySdk.IsPaused()!;
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
            return ClaritySdk.CurrentSessionId;
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
            return ClaritySdk.CurrentSessionUrl;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "{methodName} error in Clarity SDK", nameof(CurrentSessionUrlMethod));
            return null;
        }
    }
}
