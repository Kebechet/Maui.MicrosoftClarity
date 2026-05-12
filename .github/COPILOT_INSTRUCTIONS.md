# Copilot Instructions — Maui.MicrosoftClarity

You are maintaining **Kebechet.Maui.MicrosoftClarity**, a .NET MAUI wrapper
around the Microsoft Clarity Android + iOS SDKs. The repo has three packages:

| Project | Purpose | Versioning |
|---|---|---|
| `src/Maui.MicrosoftClarity.Android/` | Android binding (consumes a checked-in `Jars/clarity-X.Y.Z.aar` from Maven Central) | `<native>.<binding-rev>` — see Android README |
| `src/Maui.MicrosoftClarity.iOS/` | iOS binding (Objective Sharpie–generated from a checked-in `Clarity.xcframework`) | `<native>.<binding-rev>` — see iOS README |
| `src/Maui.MicrosoftClarity/` | Cross-platform abstraction over both bindings | Semver, managed by release-please from conventional commits |

## When you are invoked

You're called from `bump-and-wire.yml` after an automated SDK bump landed in
this PR. One of three things happened:

1. **The binding csproj failed to build** — the C# binding generator
   (Java→C# for Android, Objective Sharpie output for iOS) is producing
   invalid code against the new native SDK. Read the `binding-build-log`
   artifact. See the *Binding generator failures* section below for the
   common fixes.
2. **The wrapper failed to compile** against the new bindings — the SDK
   introduced a breaking change. Read `wrapper-build.log` (uploaded as a PR
   artifact) for the failures.
3. **The binding gained new public APIs** that the wrapper doesn't expose
   yet — the surface diff is in the PR comment that mentioned you (and the
   `api-diff` artifact). Your job is to wire those new APIs through the
   cross-platform abstraction.

In all three cases the binding `<Version>` and the wrapper's
`<PackageReference>` have been **suffixed with `-automatic`** (a NuGet
prerelease marker). **Do not remove this suffix.** A human will strip it
during merge if they're satisfied with your work — that's the "promotion
to stable" step.

## Your job

1. **Diagnose the build failure.** Read `wrapper-build.log` (uploaded as a PR
   artifact) and the diff of `ApiDefinitions.cs` / `StructsAndEnums.cs` (iOS)
   or the binding `obj/` generated sources (Android) to find what changed.

2. **Fix the wrapper to compile** against the new binding. Make minimal,
   targeted changes — do NOT refactor unrelated code, rename existing public
   APIs, or "tidy up" things that aren't broken.

3. **Preserve the existing public API** of `Kebechet.Maui.MicrosoftClarity`
   wherever possible. If a Clarity SDK rename or removal forces a breaking
   change to the wrapper:
   - Mark the old member `[Obsolete("...", error: false)]` for one release
     before removing it, where feasible.
   - If a true breaking change is unavoidable, use `feat!:` prefix in the
     commit message and explain in the PR body.

4. **For new APIs that exist on both platforms**, add matching members on the
   cross-platform abstraction (typically `IClarityService` / its
   implementations). Match the existing C#/MAUI naming style — do not
   pass through Java/ObjC names verbatim (e.g. Java `setCustomTag` →
   wrapper `SetCustomProperty`, not `setCustomTag` or `SetCustomTag`).

5. **For APIs that exist on only one platform**, expose them as
   platform-specific extensions (in the `Platforms/Android/` or
   `Platforms/iOS/` partial classes) and add an XML doc comment noting the
   asymmetry. Do NOT throw `PlatformNotSupportedException` from the
   cross-platform interface.

6. **Update `PackageReleaseNotes`** in the wrapper csproj to describe the
   user-facing change in one line.

## Constraints

- Use **Conventional Commits** for every commit you push:
  - `chore(deps): ...` — pure dependency bumps that needed no code change
  - `feat(android): ...` / `feat(ios): ...` — new wrapped API
  - `feat: ...` — new cross-platform wrapped API
  - `feat!: ...` — breaking wrapper change
  - `fix(android): ...` / `fix(ios): ...` — bugfix in a binding/wrapper
- **Never auto-merge.** Leave the PR in `Ready for review` once it builds —
  a human reviews every wrapper change before merge.
- **Do not strip the `-automatic` suffix** from any version field. That's
  the human's call at merge time. If you regenerate or rewrite the csproj
  for any reason, preserve the suffix.
- **If you're unsure** about cross-platform semantic equivalence (e.g. an
  Android-only enum that has no obvious iOS counterpart), leave a
  `// TODO(human-review):` comment and call it out in the PR body rather
  than guessing.
- **Don't touch `Transforms/EnumFields.xml` or `Transforms/EnumMethods.xml`**
  unless the binding fails to generate without it. These are the manual
  Java→C# tweaks for the Android binding.
- **Don't bypass the binding.** If you find yourself reaching for raw
  `JNIEnv` calls or `[DllImport]`, you're probably solving the wrong problem.

## Binding generator failures

When the binding csproj itself won't build, the fix is at the binding-generator
layer — not the wrapper. Common patterns and where to fix them:

### Android (`src/Maui.MicrosoftClarity.Android/`)

The .NET Android SDK generates C# from the checked-in `Jars/clarity-X.Y.Z.aar`
at build time. When it fails, look at the build log for `BG####` errors. The
fix is almost always in one of these files:

- **`Transforms/EnumMethods.xml`** — remap Java `int` parameters to C# enums.
  Use when a Java method like `Clarity.setVisibility(int)` should accept a
  strongly-typed enum.
- **`Transforms/EnumFields.xml`** — convert Java static `int` constants into a
  C# enum type. Use when Java exposes `Clarity.MODE_FOO = 0; MODE_BAR = 1`.
- **`Transforms/Metadata.xml`** *(create if missing)* — full-power binding
  metadata: rename types, hide members, change visibility, fix type-erasure
  clashes, suppress generation entirely.

**Known patterns in this repo:**
- *Function1 type-erasure clash in ACW* — already fixed once (see the
  Android csproj's `PackageReleaseNotes`). If you see this again with a new
  callback type, add a `<remove-node>` or rename in `Metadata.xml` to break
  the duplicate signature.
- Two Java overloads that erase to the same C# signature → hide one via
  `<attr path="..." name="managedName">`.

**When to give up:** if the AAR contains genuinely-broken Kotlin metadata or
the binding generator hits a bug not fixable via Transforms, leave
`// TODO(human-review):` comments listing the BG errors and add the
`needs-human` label. Don't hack around it with reflection or DllImport.

### iOS (`src/Maui.MicrosoftClarity.iOS/`)

Sharpie generated `ApiDefinitions.cs` and `StructsAndEnums.cs` (the `[Verify]`
attrs were stripped automatically). When the build fails, look for `CS####`
errors in the binding csproj's compile step. Common fixes, all in
`ApiDefinitions.cs`:

- **Wrong nullability** — Sharpie sometimes marks ObjC `id` params as
  non-nullable when they're nullable (or vice versa). Add or remove
  `[NullAllowed]`.
- **Wrong return type** — Sharpie occasionally picks `NSObject` when the ObjC
  header declares a more specific type. Replace with the right type from
  `StructsAndEnums.cs` or the generated interface set.
- **Duplicate selectors** — Sharpie can emit the same `[Export("…")]` twice
  if ObjC has overloaded selectors via Swift. Rename one with a different
  managed C# name but keep the selector identical.
- **Missing `[BaseType]`** — if a new generated interface inherits from a
  type Sharpie didn't recognize, add the correct `[BaseType(typeof(…))]`.
- **`NSString` vs `string` mismatches** — Sharpie sometimes generates raw
  `NSString` parameters; bind them as `string` so consumers don't have to
  wrap.

**When to give up:** if Sharpie produced fundamentally wrong output for a
new ObjC pattern (e.g. blocks with unusual signatures), leave
`// TODO(human-review):` comments and add `needs-human`. Don't manually
rewrite the xcframework or patch the .h headers.

## Repo conventions to mirror

- Comments only when the **why** is non-obvious. Don't narrate what the code
  does.
- Use `IsNullOrEmpty()` from `Kebechet.Extensions.IsNullOrEmpty` (namespace
  `IsNullOrEmpty.Extensions`) for null/empty checks on collections and
  strings — not manual null + `Any()`/`Length` checks.
- Don't remove comments that explain non-obvious behavior or the reason
  behind a decision (workarounds, environment-specific behavior, edge cases).
- If you touch a `scripts/*.sh` or inline workflow `run:` block, keep it
  portable across GNU and BSD userlands — the same scripts run on
  `ubuntu-latest`, `macos-15`, and `windows-latest` (Git Bash). In
  particular: no `grep -P` (PCRE / lookaround) and no `find -quit`. Use
  `sed -n -E 's|.*<Tag>([^<]+)</Tag>.*|\1|p'` for XML extraction, and
  `find … | head -1` instead of `-quit`.

## What success looks like

- `dotnet build src/Maui.MicrosoftClarity/Maui.MicrosoftClarity.csproj` is green.
- The PR title and commits follow Conventional Commits.
- The PR body lists, in plain English, every public API that changed in the
  wrapper and why.
- All `[Obsolete]` annotations have a clear migration message.
