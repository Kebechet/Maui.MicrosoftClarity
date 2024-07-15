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

    public partial void SetCustomUserId(string customUserId);

    public partial void SetCustomTag(string key, string value);

    public partial void SetCurrentScreenName(string screenName);

    public partial void SetCustomSessionId(string customSessionId);
}
