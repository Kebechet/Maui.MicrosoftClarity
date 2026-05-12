# Copilot Instructions — Maui.MicrosoftClarity

A .NET MAUI wrapper around Microsoft Clarity Android + iOS SDKs. Three packages:

| Project | Purpose | Versioning |
|---|---|---|
| `src/Maui.MicrosoftClarity.Android/` | Android binding (consumes `Jars/clarity-X.Y.Z.aar` from Maven Central) | `<native>.<binding-rev>` |
| `src/Maui.MicrosoftClarity.iOS/` | iOS binding (Sharpie-generated from `Clarity.xcframework`) | `<native>.<binding-rev>` |
| `src/Maui.MicrosoftClarity/` | Cross-platform wrapper | Semver, managed by release-please |

The PR comment that mentioned you already says which step failed.

## Your job

1. Read the linked log artifact (`binding-build-log` or `wrapper-build.log`) plus the API diff embedded in the PR comment.
2. Make the minimal change that fixes the failure. No refactoring of code that wasn't broken.
3. Update `PackageReleaseNotes` in the wrapper csproj if user-facing behavior changed.

## Constraints

- **Conventional Commits.** `fix(android|ios): …` for bug fixes, `feat(android|ios): …` for new platform-specific wrapped APIs, `feat: …` for new cross-platform APIs, `feat!: …` only when a wrapper API truly breaks, `chore(deps): …` for pure bumps that needed no code change.
- **Preserve public wrapper API.** Mark removed members `[Obsolete("…", error: false)]` for one release before removing. Every `[Obsolete]` needs a clear migration message.
- **Cross-platform APIs** belong on `IClarityService` and its implementations. Match C#/MAUI naming (`SetCustomProperty`, not the Java `setCustomTag` verbatim).
- **Platform-only APIs** go in `Platforms/Android/` or `Platforms/iOS/` partial classes with an XML doc comment noting the asymmetry. **Never** throw `PlatformNotSupportedException` from the cross-platform interface.
- **Don't auto-merge.** Leave the PR `Ready for review` when it builds — a human reviews every wrapper change.
- **If unsure** about cross-platform semantic equivalence, leave a `// TODO(human-review):` comment and call it out in the PR body rather than guessing.
- **Don't bypass the binding** with raw `JNIEnv` or `[DllImport]` — if you're reaching for those, you're solving the wrong problem.

## Repo conventions

- Use `IsNullOrEmpty()` from `Kebechet.Extensions.IsNullOrEmpty` (namespace `IsNullOrEmpty.Extensions`) for null/empty checks on collections and strings.
- Comments only when the **why** is non-obvious. Don't narrate what the code does. Don't remove existing comments that explain non-obvious behavior or past decisions.
- If you touch `scripts/*.sh` or a workflow `run:` block, keep it portable across GNU and BSD userlands (ubuntu / macos / windows Git Bash): no `grep -P`, no `find -quit`. Use `sed -n -E 's|.*<Tag>([^<]+)</Tag>.*|\1|p'` for XML extraction.

## If the binding csproj itself is broken (not the wrapper)

The fix is at the binding-generator layer. The workflow appends the appropriate platform guide ([agent-android-binding.md](agent-android-binding.md) or [agent-ios-binding.md](agent-ios-binding.md)) to the PR comment when the binding-broken branch fires.
