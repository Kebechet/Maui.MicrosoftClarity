[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/kebechet)

# Maui.MicrosoftClarity.iOS
- it contains bindings for Microsoft Clarity iOS library
    - https://clarity.microsoft.com/
    - https://learn.microsoft.com/en-us/clarity/mobile-sdk/ios-sdk
    - https://github.com/microsoft/clarity
- changelog: https://learn.microsoft.com/en-us/clarity/mobile-sdk/sdk-changelog#ios-sdk-changelog

## Versioning Scheme
The versioning scheme of `Maui.MicrosoftClarity.iOS` is derived from the versioning of original native android package.

### Example:
| Origninal lib version | Maui.MicrosoftClarity.iOS | Note |
|:--|:--|:--|
| 3.4.1 | 3.4.1.0 | First version of bindings for 3.4.1 |
| 3.4.1 | 3.4.1.17 | Bindings for 3.4.1 containing fixes |

# Binding creation

### Generating binding files
- On my MAC I have downloaded and installed [Objective Sharpie](https://learn.microsoft.com/en-us/xamarin/cross-platform/macios/binding/objective-sharpie/)
- I have downloaded latest package `v1.0.0` from [clarity-apps repo](https://github.com/microsoft/clarity-apps) ->  [Package.swift](https://github.com/microsoft/clarity-apps/blob/main/Package.swift) -> [xcframework.zip](https://clarityappsresources.blob.core.windows.net/ios-public/Clarity-1.0.0.xcframework.zip)
- I have extracted the `.zip` on my MAC desktop
- started terminal, then `cd ~/Desktop`
- firstly check what versions of xcode SDKs you have installed by `sharpie xcode -sdks` and use the `iphoneosXX.Y` version you have
- I used command `sharpie bind --sdk=iphoneos17.2 --output="BindingOutput" --namespace="Binding" --scope="Clarity.xcframework/ios-arm64/Clarity.framework/Headers" "Clarity.xcframework/ios-arm64/Clarity.framework/Headers/Clarity-Swift.h"`
  - this command generated `ApiDefinitions.cs` and `StructsAndEnums.cs` files

### Adjusting generated files
- I have removed all `Verify` attributes
- ✅ - Done

### ⚠️ Binding build
Currently it is not possible to build the binding from Windows with connected MAC. So you have to build this binding directly from the MAC. The final size of the nuget should be `>6MB`
- Issue: https://github.com/xamarin/xamarin-macios/issues/20905#issuecomment-2275166543

# License
This repository is licensed with the [MIT](LICENSE.txt) license.
