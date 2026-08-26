# Repairing the iOS binding after a native SDK bump

You are running inside the `TryBumpIOS` workflow on a macOS runner. `scripts/bump-ios.sh`
has just replaced `src/Maui.MicrosoftClarity.iOS/nativelib/Clarity.xcframework`, regenerated
`ApiDefinitions.cs` and `StructsAndEnums.cs` with Objective Sharpie (stripping the advisory
`[Verify]` attributes and normalizing the `using` directives), bumped `<Version>`, and
`dotnet build` failed.

## Goal

Make this command succeed, then stop:

```
dotnet build src/Maui.MicrosoftClarity.iOS/Maui.MicrosoftClarity.iOS.csproj -c Release
```

Start by reading `binding-build.log` in the repository root; the `CS####` errors point
at lines in `ApiDefinitions.cs` / `StructsAndEnums.cs`. The ObjC truth is in
`src/Maui.MicrosoftClarity.iOS/nativelib/Clarity.xcframework/ios-arm64/Clarity.framework/Headers/Clarity-Swift.h`.

## Rules

- Edit ONLY `src/Maui.MicrosoftClarity.iOS/ApiDefinitions.cs` and
  `src/Maui.MicrosoftClarity.iOS/StructsAndEnums.cs`. Every other change you make is
  discarded automatically before the verifying rebuild - the csproj, the xcframework,
  the wrapper, workflows and scripts included.
- Never change `<Version>`; never touch `nativelib/` or `src/Maui.MicrosoftClarity/`.
- Keep the surface the wrapper consumes bound: `ClaritySDK` (`InitializeWithConfig`,
  `Pause`, `Resume`, `IsPaused`, `StartNewSessionWithCallback`, `MaskView`, `UnmaskView`,
  `SetCustomUserId`, `SetCustomSessionId`, `CurrentSessionId`, `CurrentSessionUrl`,
  both `SetCustomTagWithKey` overloads, `SendCustomEventWithValue`,
  `SetCurrentScreenName`, `SetOnSessionStartedCallback`, `ConsentWithAnalyticsStorage`),
  `ClarityConfig` and the enums in `StructsAndEnums.cs`. Deleting a member to make the
  build pass is not a fix.
- Keep every `[Export("selector")]` string exactly as Sharpie emitted it; only managed
  names, attributes and types may change.
- Do not run git; do not create branches or commits. The workflow commits for you.
- Minimal change: no reformatting, no unrelated cleanup, no re-adding `[Verify]`.

## Known patterns

- **`using Clarity;`** at the top of `ApiDefinitions.cs` (Sharpie copies the Swift
  module name; it is not a .NET namespace) - delete it. The bump script already does
  this; if it is back, something regenerated the file.
- **Missing `using UIKit;`** (`UIView` unresolved for `MaskView` / `UnmaskView`) - add it
  next to `using Foundation;`.
- **Wrong nullability** - Sharpie marks some `id` parameters non-nullable that are
  nullable in the header (or the reverse): add or remove `[NullAllowed]`.
- **Wrong return type** - Sharpie sometimes picks `NSObject` where the header declares a
  concrete type: use the type from the header / `StructsAndEnums.cs`.
- **Duplicate selectors** - the same `[Export("...")]` emitted twice for ObjC overloads
  surfaced through Swift: rename one managed member, keep the selector identical.
- **Missing `[BaseType]`** on a new interface: add `[BaseType(typeof(NSObject))]` (or the
  right base) and the `Name = "_TtC7Clarity..."` mangled name Sharpie printed in the
  comment above it.
- **`NSString` parameters** - bind as `string` so consumers do not have to wrap.

## Loop

Edit -> run the build command -> read the new errors -> repeat. Stop when the build
passes, or when Sharpie's output is fundamentally wrong for a new ObjC pattern that a
local edit cannot express - in that case leave both files as Sharpie generated them.

## When done

Write `fix-summary.md` in the repository root (3-8 lines of markdown): which errors you
hit, what you changed and why, and anything a reviewer should double-check. It is pasted
into the pull request. If you changed nothing, write one line saying so and why.
