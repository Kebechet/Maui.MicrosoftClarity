﻿[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/kebechet)

# Maui.MicrosoftClarity.Android
- it contains bindings for RevenueCat Android library
	- https://clarity.microsoft.com/
    - https://learn.microsoft.com/en-us/clarity/mobile-sdk/android-sdk
	- https://github.com/microsoft/clarity

## Versioning Scheme
The versioning scheme of `Maui.MicrosoftClarity.Android` is derived from the versioning of original native android package.

### Example:
| Origninal android lib | Maui.MicrosoftClarity.Android | Note |
|:--|:--|:--|
| 3.4.1 | 3.4.1.0 | First version of bindings for 3.4.1 |
| 3.4.1 | 3.4.1.17 | Bindings for 3.4.1 containing 17 fixes |

## How the binding was created
- To start create a project `Android Java library binding`
- Then files of the the library have to be downloaded. 
  - For native libraries you can use [Google maven repo](https://maven.google.com/web/index.html). 
  - For downloading this library I have used [mvnrepository.com](https://mvnrepository.com/) to 
	download the [RevenueCat v2.4.0](https://mvnrepository.com/artifact/com.microsoft.clarity/clarity/2.4.0) android library.
- [Click files->View all](https://i.imgur.com/95lzSPD.png): You have to download there files:
  - `.aar` that contains the compiled library and 
  - `-sources.jar` that is used in binding process for documenting the library.
- After download create in your project `Jars` folder and put there both files. For
  - for `.aar` set `Build Action` to: `AndroidLibrary`
  - for `-sources.jar` set `Build Action` to: `JavaSourceJar` based on this [docs](https://learn.microsoft.com/en-us/xamarin/android/deploy-test/building-apps/build-items#javasourcejar)
- Then you have to add all necessary dependencies. Dependencies of the library are showed on [mvnrepository site](https://i.imgur.com/uDh8TtN.png). Your binding library should contain all these dependencies (ideally in same `version` but until those libraries are compatible, versions are not important).
  - I  have found and added `PackageReference` for all `Xamarin/Maui` alternatives of these libraries
  - ⚠️ When I wanted to use newer RevenueCat `v7.3.3` with requirement of `BillingClient v6.1.0` while the newest Xamarin library was stuck at `v6.0.1` it caused build errors after inserting this project to the main MAUI app. Rule of thumb is that usually libraries are back compatible but not forward compatible. So when it requires newer version it could be a problem but when you have newer version of the package it could be okay(depends if some breaking changes were introduced).
- ⚠️ Even after finding all mentioned libraries I had some warnings regarding some `amazon` method calls and build error `androidx.collection.ArrayMapKt is defined multiple times`
  - the amazon problem was fixed by including package `Eddys.Amazon.AppStoreSdk.Binding`
  - and the compilation error by including `Xamarin.AndroidX.Fragment.Ktx`. 
	- I found this in the source: [purchases-android-main\purchases-android-main\api-tester\build.gradle](https://github.com/RevenueCat/purchases-android/blob/main/api-tester/build.gradle#L59) at the end and it is present also in [gradle\libs.versions.toml](https://github.com/RevenueCat/purchases-android/blob/main/gradle/libs.versions.toml#L38)
- After providing all necessary libraries you have to adjust `Metadata.xml` to get rid of compilation errors. - [docs](https://learn.microsoft.com/en-us/xamarin/android/platform/binding-java-library/customizing-bindings/java-bindings-metadata)
- ⚠️ At the end there are still 2 important warnings left with `kotlin.jvm.functions.Function1` and `kotlin.jvm.internal.IntCompanionObject` but even with them the binding works correctly
- I hope this helped and enjoy the binding ❤️

# License
This repository is licensed with the [MIT](LICENSE.txt) license.
