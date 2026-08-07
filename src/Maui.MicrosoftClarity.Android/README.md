[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/kebechet)

# Maui.MicrosoftClarity.Android
[![NuGet Version](https://img.shields.io/nuget/v/Kebechet.Maui.MicrosoftClarity.Android)](https://www.nuget.org/packages/Kebechet.Maui.MicrosoftClarity.Android/)
[![NuGet Downloads](https://img.shields.io/nuget/dt/Kebechet.Maui.MicrosoftClarity.Android)](https://www.nuget.org/packages/Kebechet.Maui.MicrosoftClarity.Android/)
![Last updated (main)](https://img.shields.io/github/last-commit/Kebechet/Maui.MicrosoftClarity/main?path=src%2FMaui.MicrosoftClarity.Android&label=last%20updated)
[![Twitter](https://img.shields.io/twitter/url/https/twitter.com/samuel_sidor.svg?style=social&label=Follow%20samuel_sidor)](https://x.com/samuel_sidor)

Thic repo contains bindings for Microsoft Clarity Android library
- https://clarity.microsoft.com/
- https://learn.microsoft.com/en-us/clarity/mobile-sdk/android-sdk
- https://github.com/microsoft/clarity
- changelog: https://learn.microsoft.com/en-us/clarity/mobile-sdk/sdk-changelog#android-sdk-changelog

## Versioning Scheme
The versioning scheme of `Maui.MicrosoftClarity.Android` is derived from the versioning of original native android package.

### Example:
| Origninal lib version | Maui.MicrosoftClarity.Android | Note |
|:--|:--|:--|
| 3.4.1 | 3.4.1.0 | First version of bindings for 3.4.1 |
| 3.4.1 | 3.4.1.17 | Bindings for 3.4.1 containing 17 fixes |

## How the binding was created
- To start create a project `Android Java library binding`
- Reference the native library straight from Maven Central with
	[`AndroidMavenLibrary`](https://learn.microsoft.com/en-us/dotnet/android/binding-libs/binding-java-libs/binding-java-maven-library)
	instead of committing an `.aar` into a `Jars` folder:
	```xml
	<AndroidMavenLibrary Include="com.microsoft.clarity:clarity" Version="3.8.2" />
	```
	The AAR is downloaded when **this binding** is built and baked into the nupkg, so consumers
	need no Java, no Gradle and no build-time downloads.
- Then you have to add all necessary dependencies. Your binding library should contain all these dependencies (ideally in same `version` but until those libraries are compatible, versions are not important).
  - I have found and added `PackageReference` for all `Xamarin/Maui` alternatives of these libraries
- The artifact's POM is downloaded alongside the AAR and drives **Java dependency verification**,
	so a missing dependency now fails the build with `XA4241`/`XA4242` naming exactly what is
	missing — the `PackageReference` list is cross-checked on every SDK bump instead of being
	hand-curated.
  - A package that doesn't advertise which Maven artifact it fulfills (no `artifact_versioned=`
	nuspec tag) has to say so via `JavaArtifact="group:id:version"` metadata on its
	`PackageReference`.
  - A POM dependency that genuinely isn't needed is excluded with
	`<AndroidIgnoredJavaDependency Include="group:id:version" />`.

# License
This repository is licensed with the [MIT](LICENSE.txt) license.
