namespace Maui.MicrosoftClarity.Extensions;

internal static class JavaBooleanExtensions
{
#pragma warning disable CA1422 // Java.Lang.Boolean constructor is the required way to call this native API
    public static Java.Lang.Boolean ToJavaBoolean(this bool value) => new(value);
#pragma warning restore CA1422

    public static Java.Lang.Boolean? ToJavaBoolean(this bool? value) => value.HasValue ? value.Value.ToJavaBoolean() : null;
}
