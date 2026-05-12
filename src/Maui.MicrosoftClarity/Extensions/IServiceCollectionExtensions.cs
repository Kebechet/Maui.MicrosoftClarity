using Maui.MicrosoftClarity.Services;

namespace Maui.MicrosoftClarity.Extensions;

/// <summary>
/// DI extension methods for registering the Microsoft Clarity wrapper.
/// </summary>
public static class IServiceCollectionExtensions
{
    /// <summary>
    /// Registers <see cref="IMicrosoftClarityService"/> (backed by <see cref="MicrosoftClarityService"/>)
    /// as a singleton. Consumers should depend on the interface, not the concrete type.
    /// </summary>
    public static IServiceCollection AddMicrosoftClarity(this IServiceCollection services)
    {
        services.AddSingleton<IMicrosoftClarityService, MicrosoftClarityService>();

        return services;
    }
}
