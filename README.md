[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/kebechet)

# Maui.MicrosoftClarity
[![NuGet Version](https://img.shields.io/nuget/v/Kebechet.Maui.MicrosoftClarity)](https://www.nuget.org/packages/Kebechet.Maui.MicrosoftClarity/)
[![NuGet Downloads](https://img.shields.io/nuget/dt/Kebechet.Maui.MicrosoftClarity)](https://www.nuget.org/packages/Kebechet.Maui.MicrosoftClarity/)
![Last updated (main)](https://img.shields.io/github/last-commit/Kebechet/Maui.MicrosoftClarity/main?label=last%20updated)
[![Twitter](https://img.shields.io/twitter/url/https/twitter.com/samuel_sidor.svg?style=social&label=Follow%20samuel_sidor)](https://x.com/samuel_sidor)

Wrapper for [Microsoft Clarity for mobile](https://clarity.microsoft.com/)

## Usage
Firstly register package installer in your `MauiProgram.cs`
```csharp
 builder.Services.AddMicrosoftClarity();
```

then in `App.xaml.cs` inject `IMicrosoftClarityService`:
```csharp
public partial class App : Application {
    private readonly IMicrosoftClarityService _microsoftClarityService;

    public App(IMicrosoftClarityService microsoftClarityService) {
        InitializeComponent();
        _microsoftClarityService = microsoftClarityService;
    }
}
```
and also override there method `OnStart()` to call `_microsoftClarityService.Initialize` with your project id.

```csharp
protected override void OnStart() {
    _microsoftClarityService.Initialize("<MicrosoftClarityProjectIdHere>");

    base.OnStart();
}
```

## ⚠️ iOS Local debugging
Because of MAUI and VS bugs:
- https://github.com/xamarin/xamarin-macios/issues/19229
- https://developercommunity.visualstudio.com/t/MAUI---Cannot-create-native-types-when-d/10180586
- potential workaround: https://github.com/dotnet/maui/issues/10800#issuecomment-1301564278

it is not possible to run your app with hot-restart(direct local iOS deploy from VS for Windows)

## Dummy classes

So that you dont have to specify platform for this package and it's calls, also Windows and MacCatalyst are added with dummy implementations. When you call one of their methods you will always get:
- `true` for bool returns
- `new List<>` for collections
- `string.Empty` for string values

## Exception behavior
- Library will throw exceptions only in case developer did some mistake
- in other cases, when there is some corrupted state it will return default value of that type.

## Automated SDK updates

This repo watches Microsoft's Clarity Android and iOS SDKs and bumps this package
automatically. It runs in two independent stages so that the wrapper is only ever
moved onto a binding that is **already live on nuget.org** — that way `main` never
references a package that does not exist yet.

### Stage 1 — `build-binding.yml`

Daily at 06:00 UTC, or on demand (`workflow_dispatch` takes a platform and an
optional explicit version, for when a release drops and you don't want to wait).

```mermaid
flowchart TD
    A[Microsoft ships new Clarity SDK] --> B[06:00 UTC daily<br/>or manual dispatch]
    B --> C{Pinned version<br/>== target?}
    C -->|yes| Z[Nothing to do]
    C -->|no| D[Bump BINDING csproj only<br/>wrapper untouched]
    D --> E[Open PR + build the binding]
    E --> F{Compiles?}
    F -->|no| G[Label: binding-broken<br/>Ping @copilot<br/>PR stays open]
    F -->|yes| H[Squash-merge to main]
    H --> I[Publish binding to NuGet.org]

    G --> J{Agent can fix?}
    J -->|yes| E
    J -->|no| K[Label: needs-human]

    classDef happy fill:#d4edda,stroke:#155724,color:#000
    classDef warn fill:#fff3cd,stroke:#856404,color:#000
    classDef human fill:#f8d7da,stroke:#721c24,color:#000
    class H,I,Z happy
    class G,J warn
    class K human
```

Auto-merge is safe here precisely because the wrapper is untouched: nothing else
in the repo depends on the binding csproj, so `main` keeps referencing the
previously-published binding and stays restorable throughout. Publishing is
automatic, and the gate is the build — nothing reaches NuGet unless the binding
compiled and the PR merged.

### Stage 2 — wrapper

Runs separately, and starts by asking whether the new binding is **actually
restorable from nuget.org** yet (indexing lags publication, sometimes by hours).
If it isn't, it does nothing and tries again later, so the schedule is a tuning
knob rather than a race. Once the binding is live it bumps the wrapper's
`PackageReference`, builds against nuget.org, and either auto-merges a clean bump
or pings @copilot with the native API diff. release-please then cuts the wrapper
release.

The only manual steps for you:
1. Review and merge agent wiring PRs when `needs-wiring` is applied
2. Fix binding-generator failures the agent escalates as `needs-human` (rare)
3. Merge the release-please PR to cut a wrapper version

See `.github/COPILOT_INSTRUCTIONS.md` for the rules the agent follows.

## Contributions
Feel free to create an issue or pull request. In case you would like to do massive changes in the package please firstly discuss them in the issue because otherwise there is high chance that such big PR would be rejected.

## License
This repository is licensed with the [MIT](LICENSE.txt) license.
