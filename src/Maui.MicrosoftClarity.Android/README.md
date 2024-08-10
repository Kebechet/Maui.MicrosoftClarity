[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/kebechet)

# Maui.MicrosoftClarity.Android
![NuGet Version](https://img.shields.io/nuget/v/Kebechet.Maui.MicrosoftClarity.Android)
![NuGet Downloads](https://img.shields.io/nuget/dt/Kebechet.Maui.MicrosoftClarity.Android)

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
- Then files of the the library have to be downloaded. 
- Download native library from: [mvnrepository.com](https://mvnrepository.com/artifact/com.microsoft.clarity/clarity) to 
	download the [Clarity v2.4.0](https://mvnrepository.com/artifact/com.microsoft.clarity/clarity/2.4.0) android library.
- Click: `files->View all`. You have to download there files:
  - `.aar` that contains the compiled library and 
  - `-sources.jar` that is used in binding process for documenting the library.
- After download create in your project `Jars` folder and put there both files. For
  - for `.aar` set `Build Action` to: `AndroidLibrary`
  - for `-sources.jar` set `Build Action` to: `JavaSourceJar` based on this [docs](https://learn.microsoft.com/en-us/xamarin/android/deploy-test/building-apps/build-items#javasourcejar)
- Then you have to add all necessary dependencies. Your binding library should contain all these dependencies (ideally in same `version` but until those libraries are compatible, versions are not important).
  - I  have found and added `PackageReference` for all `Xamarin/Maui` alternatives of these libraries

# License
This repository is licensed with the [MIT](LICENSE.txt) license.
