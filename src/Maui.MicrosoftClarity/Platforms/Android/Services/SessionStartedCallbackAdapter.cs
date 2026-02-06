using Com.Microsoft.Clarity;

namespace Maui.MicrosoftClarity.Services;

internal sealed class SessionStartedCallbackAdapter : Java.Lang.Object, ISessionStartedCallback
{
    private readonly Action<string> _callback;

    public SessionStartedCallbackAdapter(Action<string> callback)
    {
        _callback = callback;
    }

    public SessionStartedCallbackAdapter(TaskCompletionSource<string?> tcs)
        : this(sessionId => tcs.TrySetResult(sessionId))
    {
    }

    public Kotlin.Unit? Invoke(string? sessionId)
    {
        if (sessionId is not null)
        {
            _callback(sessionId);
        }

        return null;
    }

    public Java.Lang.Object? Invoke(Java.Lang.Object? p0)
    {
        if (p0 is Java.Lang.String javaString)
        {
            _callback(javaString.ToString());
        }

        return null;
    }
}
