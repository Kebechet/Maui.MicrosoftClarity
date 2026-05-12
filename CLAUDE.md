# Maui.MicrosoftClarity — project notes

## Public API surface & DI

The cross-platform contract is the interface `IMicrosoftClarityService`
(`src/Maui.MicrosoftClarity/Services/IMicrosoftClarityService.cs`).
The concrete `MicrosoftClarityService` is a `partial class` split per platform
(Android / iOS / MacCatalyst / Windows). `AddMicrosoftClarity()` registers the
interface mapping as a singleton:

```csharp
services.AddSingleton<IMicrosoftClarityService, MicrosoftClarityService>();
```

**Consumers MUST depend on `IMicrosoftClarityService`, not the concrete class.**
The concrete type is not registered standalone — resolving it directly will fail.

## Where XML documentation lives

All public API XML docs live on `IMicrosoftClarityService`. The concrete partial
methods/properties use `/// <inheritdoc/>` so IntelliSense works regardless of
whether the consumer holds an interface or concrete reference. When adding new
public surface, the workflow is:

1. Add the member to the interface with a `<summary>` (and `<param>` / `<returns>`
   / `<remarks>` as appropriate).
2. Add the matching partial method/property to `MicrosoftClarityService.cs` with
   `/// <inheritdoc/>`.
3. Implement the body in each `Platforms/<plat>/Services/MicrosoftClarityService<plat>.cs`.

Documentation wording should be **adapted from the official Microsoft Learn docs**
to stay authoritative:
- Android: https://learn.microsoft.com/en-us/clarity/mobile-sdk/android-sdk
- iOS:     https://learn.microsoft.com/en-us/clarity/mobile-sdk/ios-sdk

If platform behavior diverges (e.g. `Consent` ignores `isAdsStorageAllowed` on
iOS), call it out explicitly in the interface's `<remarks>` — the interface is
the single source of truth that consumers will read.

## Disposal

`IMicrosoftClarityService` deliberately does NOT extend `IDisposable`. Only the
Android partial implements `IDisposable` (to release a `SessionStartedCallbackAdapter`).
DI's runtime disposable detection handles cleanup on container shutdown for the
singleton registration; consumers do not need to manage disposal manually.

## Versioning

This package uses release-please. The `<Version>` line in
`src/Maui.MicrosoftClarity/Maui.MicrosoftClarity.csproj` is marked with
`<!-- x-release-please-version -->` and is updated automatically — never bump it
in a feature PR. Use conventional commit prefixes (`feat:`, `fix:`, `feat!:` for
breaking, etc.); release-please derives the version bump and changelog from there.
