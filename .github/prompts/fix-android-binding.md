# Repairing the Android binding after a native SDK bump

You are running inside the `TryBumpAndroid` workflow. `scripts/bump-android.sh` has just
moved `src/Maui.MicrosoftClarity.Android/Maui.MicrosoftClarity.Android.csproj` onto a new
`com.microsoft.clarity:clarity` version and `dotnet build` failed. The .NET Android SDK
downloads that AAR from Maven Central and generates C# from it at build time, so the only
lever is the binding metadata under `src/Maui.MicrosoftClarity.Android/Transforms/`.

## Goal

Make this command succeed, then stop:

```
dotnet build src/Maui.MicrosoftClarity.Android/Maui.MicrosoftClarity.Android.csproj -c Release
```

Start by reading `binding-build.log` in the repository root. The `BG####` / `CS####`
errors name the Java type or member at fault; `BG8605` warnings about types in
`com.microsoft.clarity.protomodels` or obfuscated packages are pre-existing noise, not
the failure.

## Rules

- Edit ONLY files under `src/Maui.MicrosoftClarity.Android/Transforms/`
  (`Metadata.xml`, `EnumFields.xml`, `EnumMethods.xml`). Every other change you make is
  discarded automatically before the verifying rebuild - the csproj, the wrapper,
  workflows and scripts included.
- Never change `<Version>` or the `<AndroidMavenLibrary>` pin. Never touch
  `src/Maui.MicrosoftClarity/`.
- Keep the surface the wrapper consumes bound: `com.microsoft.clarity.Clarity`
  (managed name `ClaritySdk`), `ClarityConfig`, `SessionStartedCallback` and everything
  in `com.microsoft.clarity.models`. Removing a member the wrapper uses just to make the
  build pass is not a fix - prefer renaming (`managedName`) or removing the *conflicting*
  overload or internal member instead.
- Do not run git; do not create branches or commits. The workflow commits for you.
- Minimal change: no reformatting, no unrelated cleanup. Keep the existing XML comments -
  they record why each transform exists - and add one above each transform you add,
  naming the error it resolves.

## Known patterns

- **Type-erasure clash in the ACW** (`... is defined multiple times`, duplicate
  signature after erasure of `Function0` / `Function1` ...): remove the redundant
  `implements` node - see the existing `SessionStartedCallback` fix in `Metadata.xml`.
- **Obfuscated internal packages breaking generation** (`com.microsoft.clarity.a`,
  `.b`, ...): the first `remove-node` in `Metadata.xml` already drops every package
  except `com.microsoft.clarity` and `com.microsoft.clarity.models`. Extend that filter
  rather than adding per-class removals.
- **Java overloads erasing to the same C# signature**: hide or rename one with
  `<attr path="..." name="managedName">NewName</attr>`.
- **Type name equal to its namespace (BG8403)**: `managedName` attr, as done for
  `Clarity` -> `ClaritySdk`.
- **`int` parameters or constants that should be enums**: `EnumMethods.xml` /
  `EnumFields.xml`.

## Loop

Edit -> run the build command -> read the new errors -> repeat. Stop when the build
passes, or when you are convinced the failure is a generator bug that metadata cannot
fix - in that case leave the Transforms untouched.

## When done

Write `fix-summary.md` in the repository root (3-8 lines of markdown): which errors you
hit, what you changed and why, and anything a reviewer should double-check. It is pasted
into the pull request. If you changed nothing, write one line saying so and why.
