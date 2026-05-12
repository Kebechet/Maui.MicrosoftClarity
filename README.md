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

then in `App.xaml.cs` inject `MicrosoftClarityService`:
```csharp
public partial class App : Application {
    private readonly MicrosoftClarityService _microsoftClarityService;

    public App(MicrosoftClarityService microsoftClarityService) {
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

This repo runs a daily pipeline that watches Microsoft's Clarity Android and iOS SDKs and tries to bump + re-wire this package automatically. The flow:

```mermaid
flowchart TD
    A[Microsoft ships new Clarity SDK] --> B[06:00 UTC daily<br/>automatic-detect-sdk-updates.yml]
    B --> C[Bump PR opened<br/>label: auto-bump]
    C --> D[automatic-bump-and-wire.yml:<br/>build binding + diff API + build wrapper]

    D --> E{Outcome?}

    E -->|API unchanged<br/>wrapper compiles| F[Auto-merge as<br/>stable release]
    E -->|API additions<br/>or wrapper breaks| G[Label: needs-wiring<br/>Ping @copilot<br/>with API diff]
    E -->|Binding itself broken| H[Label: binding-broken<br/>Ping @copilot<br/>with binding-fix guide]

    G --> K[Agent commits wiring]
    H --> L{Agent can fix?}
    L -->|yes| K
    L -->|no| M[Agent adds label:<br/>needs-human]

    K --> N[Human review + merge]
    M --> N
    F --> O[main updated]
    N --> O

    O --> R[release-please<br/>maintains release PR<br/>for wrapper version]
    R --> S[Merge release PR<br/>tags vX.Y.Z]
    S --> T[Manually run<br/>publish-*.yml workflows]
    T --> U[NuGet.org]

    classDef happy fill:#d4edda,stroke:#155724,color:#000
    classDef warn fill:#fff3cd,stroke:#856404,color:#000
    classDef human fill:#f8d7da,stroke:#721c24,color:#000
    class F,O,U happy
    class G,H,K warn
    class M,N human
```

The only manual steps for you:
1. Review and merge agent wiring PRs when `needs-wiring` is applied
2. Fix binding-generator failures the agent escalates as `needs-human` (rare)
3. Trigger the three `publish-*.yml` workflows after each release tag

See `.github/COPILOT_INSTRUCTIONS.md` for the rules the agent follows.

## Contributions
Feel free to create an issue or pull request. In case you would like to do massive changes in the package please firstly discuss them in the issue because otherwise there is high chance that such big PR would be rejected.

## License
This repository is licensed with the [MIT](LICENSE.txt) license.
