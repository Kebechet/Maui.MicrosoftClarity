namespace Maui.MicrosoftClarity.Services;

/// <summary>
/// Cross-platform abstraction over the Microsoft Clarity mobile SDKs.
/// All methods should be called on the main thread, matching the underlying native SDK contracts.
/// </summary>
/// <remarks>
/// Method descriptions are adapted from the official Microsoft Learn references:
/// <list type="bullet">
///   <item><description><see href="https://learn.microsoft.com/en-us/clarity/mobile-sdk/android-sdk"/></description></item>
///   <item><description><see href="https://learn.microsoft.com/en-us/clarity/mobile-sdk/ios-sdk"/></description></item>
/// </list>
/// Windows and MacCatalyst implementations are no-op stubs that return default values
/// (<see langword="true"/> for bool, <see cref="string.Empty"/> for strings, <see langword="null"/> for nullable strings).
/// </remarks>
public interface IMicrosoftClarityService
{
    /// <summary>
    /// Initializes Clarity to start capturing the current session's data. Call once during app startup
    /// (typically <c>App.OnStart</c>) on the main thread.
    /// </summary>
    /// <param name="projectId">
    /// The unique identifier of your Clarity project, found on the Settings page of the Clarity dashboard.
    /// </param>
    /// <remarks>
    /// Initialization is asynchronous — the call returns before Clarity is fully initialized. For logic
    /// that requires a started session, register a handler via
    /// <see cref="SetOnSessionStartedCallback(Action{string})"/>.
    /// </remarks>
    void Initialize(string projectId);

    /// <summary>
    /// <see langword="true"/> when session capturing is currently paused (after a prior <see cref="Pause"/> call);
    /// otherwise <see langword="false"/>.
    /// </summary>
    bool IsPaused { get; }

    /// <summary>
    /// The ID of the currently active Clarity session, or <see langword="null"/> if no session has started yet.
    /// Useful for correlating Clarity sessions with other telemetry.
    /// </summary>
    /// <remarks>
    /// To guarantee a non-<see langword="null"/> value, read this from within a
    /// <see cref="SetOnSessionStartedCallback(Action{string})"/> or <see cref="StartNewSession"/> callback.
    /// </remarks>
    string? CurrentSessionId { get; }

    /// <summary>
    /// The URL of the current Clarity session recording on the Clarity dashboard, or <see langword="null"/>
    /// if no session has started yet.
    /// </summary>
    /// <remarks>
    /// To guarantee a non-<see langword="null"/> value, read this from within a
    /// <see cref="SetOnSessionStartedCallback(Action{string})"/> or <see cref="StartNewSession"/> callback.
    /// </remarks>
    string? CurrentSessionUrl { get; }

    /// <summary>
    /// Pauses Clarity session capturing until <see cref="Resume"/> is called.
    /// </summary>
    void Pause();

    /// <summary>
    /// Resumes Clarity session capturing after a prior <see cref="Pause"/> call.
    /// </summary>
    void Resume();

    /// <summary>
    /// Sets a custom user ID for the current session, usable for filtering on the Clarity dashboard.
    /// </summary>
    /// <param name="customUserId">
    /// A non-empty, non-whitespace string up to 255 characters. Do NOT pass Personally Identifiable Information (PII).
    /// </param>
    /// <returns><see langword="true"/> if the custom user ID was set successfully; otherwise <see langword="false"/>.</returns>
    /// <remarks>
    /// To ensure the user ID is attached to the intended session, call this from within a
    /// <see cref="SetOnSessionStartedCallback(Action{string})"/> or <see cref="StartNewSession"/> callback.
    /// </remarks>
    bool SetCustomUserId(string customUserId);

    /// <summary>
    /// Sets a custom key/value tag on the current session, usable for filtering on the Clarity dashboard.
    /// </summary>
    /// <param name="key">A non-empty, non-whitespace string up to 255 characters.</param>
    /// <param name="value">A non-empty, non-whitespace string up to 255 characters.</param>
    /// <returns><see langword="true"/> if the tag was set successfully; otherwise <see langword="false"/>.</returns>
    /// <remarks>
    /// To ensure the tag is attached to the intended session, call this from within a
    /// <see cref="SetOnSessionStartedCallback(Action{string})"/> or <see cref="StartNewSession"/> callback.
    /// </remarks>
    bool SetCustomTag(string key, string value);

    /// <summary>
    /// Overrides the screen name reported to Clarity, replacing the default name derived from the current
    /// Activity (Android) or view controller (iOS). Clarity starts a new page whenever the screen name changes.
    /// </summary>
    /// <param name="screenName">A non-empty, non-whitespace string up to 255 characters.</param>
    /// <returns><see langword="true"/> if the screen name was set successfully; otherwise <see langword="false"/>.</returns>
    /// <remarks>
    /// The custom name persists across subsequent screens until set again. For accurate tracking, call
    /// this immediately after navigating to the new screen — typically from a MAUI page-navigation handler.
    /// </remarks>
    bool SetCurrentScreenName(string screenName);

    /// <summary>
    /// Sets a custom session ID for the current session, usable for filtering on the Clarity dashboard.
    /// </summary>
    /// <param name="customSessionId">A non-empty, non-whitespace string up to 255 characters.</param>
    /// <returns><see langword="true"/> if the custom session ID was set successfully; otherwise <see langword="false"/>.</returns>
    /// <remarks>
    /// To ensure the session ID is attached to the intended session, call this from within a
    /// <see cref="SetOnSessionStartedCallback(Action{string})"/> or <see cref="StartNewSession"/> callback.
    /// </remarks>
    bool SetCustomSessionId(string customSessionId);

    /// <summary>
    /// Sends a custom event to the current Clarity session. Use this to track interactions that Clarity's
    /// built-in tracking does not capture automatically.
    /// </summary>
    /// <param name="value">
    /// The event name. A non-empty, non-whitespace string up to 254 characters.
    /// </param>
    /// <returns><see langword="true"/> if the event was sent successfully; otherwise <see langword="false"/>.</returns>
    /// <remarks>
    /// Each event is logged individually and can be filtered, viewed, and analyzed on the Clarity dashboard.
    /// </remarks>
    bool SendCustomEvent(string value);

    /// <summary>
    /// Registers a callback invoked whenever a new Clarity session starts (or an existing session is
    /// resumed at app startup). The callback receives the session ID and runs on the main thread.
    /// </summary>
    /// <param name="callback">The handler to invoke on session start.</param>
    /// <returns><see langword="true"/> if the callback was set successfully; otherwise <see langword="false"/>.</returns>
    /// <remarks>
    /// If a session has already started when the callback is registered, the callback fires immediately
    /// with the current session ID.
    /// </remarks>
    bool SetOnSessionStartedCallback(Action<string> callback);

    /// <summary>
    /// Forces Clarity to start a new session asynchronously and returns its ID once it begins
    /// (or <see langword="null"/> if a new session could not be started).
    /// </summary>
    /// <returns>The new session ID, or <see langword="null"/> if a new session could not be started.</returns>
    /// <remarks>
    /// Events that occur before the task completes are associated with the previous session. Use the
    /// returned ID (or the <see cref="SetOnSessionStartedCallback(Action{string})"/> callback) to attach
    /// custom tags, user IDs, or session IDs to the new session.
    /// </remarks>
    Task<string?> StartNewSession();

    /// <summary>
    /// Sets the user's consent for data collection. Call after obtaining consent (e.g. via a consent banner).
    /// </summary>
    /// <param name="isAdsStorageAllowed">
    /// Whether the user consents to ads data collection. Forwarded to the native SDK on Android; ignored on iOS
    /// (the iOS SDK does not support ads-storage consent).
    /// </param>
    /// <param name="isAnalyticsStorageAllowed">Whether the user consents to analytics data collection.</param>
    /// <returns><see langword="true"/> if consent was applied successfully; otherwise <see langword="false"/>.</returns>
    /// <remarks>
    /// On Android, the native SDK rejects the call (returns <see langword="false"/>) if either argument is
    /// <see langword="null"/>. On iOS, this wrapper returns <see langword="false"/> when
    /// <paramref name="isAnalyticsStorageAllowed"/> is <see langword="null"/>.
    /// </remarks>
    bool Consent(bool? isAdsStorageAllowed, bool? isAnalyticsStorageAllowed);
}
