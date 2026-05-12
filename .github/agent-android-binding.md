# Android binding fixes

The .NET Android SDK generates C# from the checked-in `Jars/clarity-X.Y.Z.aar` at build time. When it fails, look at `binding-build-log` for `BG####` errors. The fix is almost always in one of:

- **`Transforms/EnumMethods.xml`** — remap Java `int` parameters to C# enums. Use when a Java method like `Clarity.setVisibility(int)` should accept a strongly-typed enum.
- **`Transforms/EnumFields.xml`** — convert Java static `int` constants into a C# enum type. Use when Java exposes `Clarity.MODE_FOO = 0; MODE_BAR = 1`.
- **`Transforms/Metadata.xml`** *(create if missing)* — full-power binding metadata: rename types, hide members, fix type-erasure clashes, suppress generation entirely.

## Known patterns

- **Function1 type-erasure clash in ACW** — already fixed once (see Android csproj's `PackageReleaseNotes`). New callback types with the same issue: add `<remove-node>` or rename in `Metadata.xml` to break the duplicate signature.
- **Java overloads erasing to the same C# signature** — hide one via `<attr path="..." name="managedName">`.

## When to give up

Genuinely-broken Kotlin metadata or a generator bug unfixable via Transforms: leave `// TODO(human-review):` comments listing the BG errors, add the `needs-human` label. Don't hack around with reflection or DllImport.
