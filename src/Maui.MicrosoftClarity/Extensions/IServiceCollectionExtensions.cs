using Maui.MicrosoftClarity.Services;

namespace Maui.MicrosoftClarity.Extensions;

public static class IServiceCollectionExtensions
{
    public static IServiceCollection AddMicrosoftClarity(this IServiceCollection services)
    {
        services.AddSingleton<MicrosoftClarityService>();

        return services;
    }
}
