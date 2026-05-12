# iOS binding fixes

Sharpie generated `ApiDefinitions.cs` and `StructsAndEnums.cs` (`[Verify]` attrs were stripped automatically by `scripts/bump-ios.sh`). When the build fails, look for `CS####` errors. Common fixes, all in `ApiDefinitions.cs`:

- **Wrong nullability** — Sharpie sometimes marks ObjC `id` params non-nullable when they're nullable (or vice versa). Add/remove `[NullAllowed]`.
- **Wrong return type** — Sharpie occasionally picks `NSObject` when the ObjC header declares a more specific type. Replace with the right type from `StructsAndEnums.cs`.
- **Duplicate selectors** — Sharpie can emit the same `[Export("…")]` twice for ObjC overloads via Swift. Rename one's managed C# name; keep the selector identical.
- **Missing `[BaseType]`** — a new generated interface inheriting from an unrecognized type: add `[BaseType(typeof(…))]`.
- **`NSString` vs `string` mismatches** — Sharpie sometimes generates raw `NSString` parameters; bind them as `string` so consumers don't have to wrap.

## When to give up

Sharpie produced fundamentally wrong output for a new ObjC pattern (e.g. blocks with unusual signatures): leave `// TODO(human-review):` comments, add `needs-human` label. Don't manually rewrite the xcframework or patch the .h headers.
