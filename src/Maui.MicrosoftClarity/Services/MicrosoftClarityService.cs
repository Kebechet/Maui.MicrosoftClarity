using Microsoft.Extensions.Logging;

namespace Maui.MicrosoftClarity.Services;

/// <inheritdoc cref="IMicrosoftClarityService"/>
public partial class MicrosoftClarityService : IMicrosoftClarityService
{
    private readonly ILogger<MicrosoftClarityService> _logger;

    /// <summary>
    /// Creates a new <see cref="MicrosoftClarityService"/>. Resolved by DI when registered via
    /// <c>IServiceCollectionExtensions.AddMicrosoftClarity</c>.
    /// </summary>
    public MicrosoftClarityService(ILogger<MicrosoftClarityService> logger)
    {
        _logger = logger;
    }

    /// <inheritdoc/>
    public partial void Initialize(string projectId);

    /// <inheritdoc/>
    public bool IsPaused => IsPausedMethod();
    /// <inheritdoc/>
    public string? CurrentSessionId => CurrentSessionIdMethod();
    /// <inheritdoc/>
    public string? CurrentSessionUrl => CurrentSessionUrlMethod();

    /// <inheritdoc/>
    public partial void Pause();

    /// <inheritdoc/>
    public partial void Resume();

    /// <inheritdoc/>
    public partial bool SetCustomUserId(string customUserId);

    /// <inheritdoc/>
    public partial bool SetCustomTag(string key, string value);

    /// <inheritdoc/>
    public partial bool SetCurrentScreenName(string screenName);

    /// <inheritdoc/>
    public partial bool SetCustomSessionId(string customSessionId);

    /// <inheritdoc/>
    public partial bool SendCustomEvent(string value);

    /// <inheritdoc/>
    public partial bool SetOnSessionStartedCallback(Action<string> callback);

    /// <inheritdoc/>
    public partial Task<string?> StartNewSession();

    /// <inheritdoc/>
    public partial bool Consent(bool? isAdsStorageAllowed, bool? isAnalyticsStorageAllowed);
}
