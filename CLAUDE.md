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

## Scripts and workflows

**No second scripting language.** This is a .NET repository: anything beyond thin shell
glue is a **.NET 10 file-based app** - a plain `.cs` run with `dotnet run script.cs -- args`,
no csproj, no project file. Do NOT reach for Perl, Python, Ruby or Node to parse XML,
JSON or HTML; `scripts/clarity.cs` is the one place that logic belongs, and it grows new
subcommands instead of new languages. The SDK is already installed on every runner and on
every machine that builds this repo, so there is nothing extra to provision.

`scripts/*.sh` stay thin: `curl`, `gh`, `git`, `dotnet`, `unzip`, `sharpie`, control flow.
They run on ubuntu, macOS and Windows Git Bash, so keep them portable - no `grep -P`, no
`find -quit`. Never rewrite a file in place with `sed -i`: Git Bash's sed strips CRLF line
endings, which silently rewrote every line of a csproj once. File rewriting goes through
`clarity.cs`, which preserves each file's BOM and line endings byte-for-byte.

The automated SDK bumps live in `.github/workflows/try-bump-android.yml` and
`try-bump-ios.yml`; the prompts Claude Code follows when a bumped binding does not build
are `.github/prompts/fix-<platform>-binding.md`. A bump PR touches only the binding
project - never the wrapper's binding `PackageReference`.

## Versioning

This package uses release-please. The `<Version>` line in
`src/Maui.MicrosoftClarity/Maui.MicrosoftClarity.csproj` is marked with
`<!-- x-release-please-version -->` and is updated automatically — never bump it
in a feature PR. Use conventional commit prefixes (`feat:`, `fix:`, `feat!:` for
breaking, etc.); release-please derives the version bump and changelog from there.

## Testing a wrapper change on real devices

The demo (`demo/DemoApp`) references the wrapper by `ProjectReference`, so it builds
whatever is in the working tree — but it still restores the **binding packages from
nuget.org**, so a wrapper move onto a new binding cannot be device-tested until that
binding is actually published and indexed.

**Android** (Pixel 6, serial `1B261FDF600DBL`):

```bash
dotnet build demo/DemoApp/DemoApp/DemoApp.csproj -f net10.0-android -c Debug \
  -p:EmbedAssembliesIntoApk=true -p:AndroidSdkDirectory="$LOCALAPPDATA\Android\Sdk"
adb -s 1B261FDF600DBL install -r demo/DemoApp/DemoApp/bin/Debug/net10.0-android/com.companyname.demoapp-Signed.apk
adb -s 1B261FDF600DBL shell am start -n com.companyname.demoapp/crc6450bbe13713f94727.MainActivity
adb -s 1B261FDF600DBL logcat -d | grep -i clarity | grep -v om.satisfit
```

⚠️ **`-p:EmbedAssembliesIntoApk=true` is required when installing with `adb install`.** A
default Debug build uses Fast Deployment, which ships an APK with no assemblies and expects
them to be pushed separately; installing that APK by hand aborts at launch with
`No assemblies found in ... .__override__`, which looks like a binding failure and is not.

⚠️ **Filter `om.satisfit` out of logcat.** SatisFIT is installed on the same phone and runs
its own Clarity, so an unfiltered `grep -i clarity` shows *its* SDK, not the demo's. A real
pass looks like `Initialize Clarity` → `Request response code (...): 200` → `Clarity started`
→ `Upload job started for session '<id>'` → `Uploaded payload ...`, plus
`Received web view analytics event Click` for the BlazorWebView path.

🛑 **iOS: sign with the existing `*` wildcard App ID, and never with `com.satisfit.app`.**
Those profiles are explicit-id, so reusing one forces the demo to take that bundle id and
overwrites the SatisFIT install on the iPhone. A wildcard development profile signs any
bundle id, so the demo keeps `com.companyname.demoapp` and nothing is replaced. Reuse an
existing DEVELOPMENT certificate: `~/satisfit-signing/asc-dev-signing.cs` on the Mac always
mints a *new* one, Apple caps them, and three already exist. Rig details are in the SatisFIT
repo's `.claude/rules/app-automation.md`.
