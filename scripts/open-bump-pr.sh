#!/usr/bin/env bash
#
# Commits the binding bump, pushes bump/<platform>-<target> and creates or refreshes its
# pull request against BASE_BRANCH. One script for both platforms so the PR contract
# lives in one place:
#   - only the binding directory is committed; the wrapper csproj must be byte-identical
#   - STATUS=green          -> ready-for-review PR
#   - STATUS=<anything else> -> DRAFT PR labelled with that status
#
# Inputs (environment):
#   PLATFORM          android | ios
#   PREVIOUS, TARGET  native SDK versions
#   BINDING_VERSION   <native>.<binding-rev>
#   BASE_BRANCH       branch the PR targets (main on the schedule; the dispatched ref otherwise)
#   STATUS            green | binding-broken | wrapper-broken | min-os-raised |
#                     upstream-breaking
#   MIN_OS_RAISED, MIN_OS_PREVIOUS, MIN_OS_CURRENT
#                     from clarity.cs check-min-os; a raised floor is breaking for
#                     consumers, so that PR opens as a draft even though it builds
#   CHANGELOG_EXCERPT optional upstream changelog line for TARGET
#   CLAUDE_FIXED      true when the Claude repair step changed sources that then built
#   FIX_SUMMARY_FILE  optional markdown written by the repair step
#   RUN_URL           link to the workflow run (build logs are attached there)
#   GH_TOKEN          token for gh (the bump-bot app token, so pushes raise events)
#   DRY_RUN           1 = commit locally but print instead of pushing / calling gh
#
# Outputs (GITHUB_OUTPUT): pr_number, pr_url, branch

set -euo pipefail

: "${PLATFORM:?}" "${PREVIOUS:?}" "${TARGET:?}" "${BINDING_VERSION:?}" "${BASE_BRANCH:?}" "${STATUS:?}"
CHANGELOG_EXCERPT="${CHANGELOG_EXCERPT:-}"
MIN_OS_RAISED="${MIN_OS_RAISED:-false}"
MIN_OS_PREVIOUS="${MIN_OS_PREVIOUS:-}"
MIN_OS_CURRENT="${MIN_OS_CURRENT:-}"
WRAPPER_OK="${WRAPPER_OK:-true}"
CLAUDE_FIXED="${CLAUDE_FIXED:-false}"
FIX_SUMMARY_FILE="${FIX_SUMMARY_FILE:-}"
RUN_URL="${RUN_URL:-}"
DRY_RUN="${DRY_RUN:-0}"

WRAPPER_CSPROJ="src/Maui.MicrosoftClarity/Maui.MicrosoftClarity.csproj"
case "$PLATFORM" in
  android)
    PLATFORM_NAME="Android"; WORKFLOW="TryBumpAndroid"; OS_NAME="Android API level"
    BINDING_DIR="src/Maui.MicrosoftClarity.Android"; TFM="net10.0-android"
    SOURCE_URL="https://central.sonatype.com/artifact/com.microsoft.clarity/clarity/${TARGET}"
    CHANGELOG_URL="https://learn.microsoft.com/en-us/clarity/mobile-sdk/sdk-changelog#android-sdk-changelog" ;;
  ios)
    PLATFORM_NAME="iOS"; WORKFLOW="TryBumpIOS"; OS_NAME="iOS"
    BINDING_DIR="src/Maui.MicrosoftClarity.iOS"; TFM="net10.0-ios"
    SOURCE_URL="https://github.com/microsoft/clarity-apps/blob/main/Package.swift"
    CHANGELOG_URL="https://learn.microsoft.com/en-us/clarity/mobile-sdk/sdk-changelog#ios-sdk-changelog" ;;
  *) echo "ERROR: unknown platform '$PLATFORM' (expected android or ios)" >&2; exit 2 ;;
esac

BRANCH="bump/${PLATFORM}-${TARGET}"
TITLE="chore(deps): bump Clarity ${PLATFORM_NAME} SDK to ${TARGET}"
# NuGet drops a trailing ".0" from a four-part version, so say what nuget.org will show.
PUBLISHED_VERSION=$(printf '%s' "$BINDING_VERSION" | sed -E 's/\.0$//')

# --- 1. Guard: the wrapper is never part of a bump ------------------------------
if ! git diff --quiet -- "$WRAPPER_CSPROJ"; then
  echo "ERROR: $WRAPPER_CSPROJ was modified; a bump PR must leave the wrapper untouched" >&2
  git --no-pager diff -- "$WRAPPER_CSPROJ" >&2
  exit 1
fi

# --- 2. Commit only the binding directory ---------------------------------------
COMMIT_BODY="From ${PREVIOUS} to ${TARGET}. Binding only - the wrapper moves onto ${BINDING_VERSION} once it is live on nuget.org."
if [[ -n "$CHANGELOG_EXCERPT" ]]; then
  COMMIT_BODY+=$'\n\n'"Upstream ${TARGET}: ${CHANGELOG_EXCERPT}"
fi
if [[ "$MIN_OS_RAISED" == "true" ]]; then
  COMMIT_BODY+=$'\n\n'"BREAKING: the native SDK raised its floor, so the binding's SupportedOSPlatformVersion moves from ${MIN_OS_PREVIOUS} to ${MIN_OS_CURRENT}."
fi
if [[ "$CLAUDE_FIXED" == "true" ]]; then
  COMMIT_BODY+=$'\n\n'"Binding sources were repaired by Claude Code so they compile against ${TARGET}; see the pull request description."
fi
if [[ "$STATUS" != "green" ]]; then
  COMMIT_BODY+=$'\n\n'"Status: ${STATUS} - opened as a draft, not mergeable as-is."
fi
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] would commit on $BRANCH (only $BINDING_DIR):"
  printf '%s\n\n%s\n\n' "$TITLE" "$COMMIT_BODY"
else
  git config user.name  "clarity-bump-bot[bot]"
  git config user.email "clarity-bump-bot[bot]@users.noreply.github.com"
  git checkout -q -B "$BRANCH"
  git add -A -- "$BINDING_DIR"
  if git diff --cached --quiet; then
    echo "ERROR: nothing to commit under $BINDING_DIR" >&2
    exit 1
  fi
  git commit -q -m "$TITLE" -m "$COMMIT_BODY"
  echo "==> committed $(git rev-parse --short HEAD) on $BRANCH"
  git --no-pager show --stat --format='%s%n%n%b' HEAD | cat
fi

# --- 3. PR body -------------------------------------------------------------------
if [[ "$STATUS" == "green" ]]; then
  STATUS_LINE="✅ **Ready to merge.** The binding builds, the wrapper compiles against it, nothing else changed."
  BUILD_LINE="✅ Binding builds (\`dotnet build -c Release\`)"
  WRAPPER_LINE="✅ Wrapper compiles against the packed binding (\`${TFM}\`, wrapper csproj untouched)"
elif [[ "$STATUS" == "binding-broken" ]]; then
  STATUS_LINE="🛑 **DRAFT - the binding does not build.** Do not merge. Fix it on this branch (or wait for the next run to retry) and mark the PR ready."
  BUILD_LINE="❌ Binding does NOT build - see the \`binding-build-log-${PLATFORM}\` artifact on the run"
  WRAPPER_LINE="⏭️ Wrapper check skipped because the binding is broken"
elif [[ "$STATUS" == "min-os-raised" ]]; then
  STATUS_LINE="🛑 **DRAFT - this bump raises the minimum ${OS_NAME} to \`${MIN_OS_CURRENT}\` (was \`${MIN_OS_PREVIOUS}\`).** The binding builds, but raising the floor is a breaking change for consumers, so it is a human decision rather than an automatic merge. Decide whether the wrapper's own \`SupportedOSPlatformVersion\` moves with it, then mark the PR ready."
  BUILD_LINE="✅ Binding builds (\`dotnet build -c Release\`)"
  if [[ "$WRAPPER_OK" == "true" ]]; then
    WRAPPER_LINE="✅ Wrapper compiles against the packed binding (\`${TFM}\`, wrapper csproj untouched)"
  else
    # Expected: NuGet will not hand a net10.0-ios16.0 asset to a project whose own
    # platform floor is lower, so this fails until the wrapper's floor moves too.
    WRAPPER_LINE="❌ Wrapper does NOT compile against it - expected while the wrapper's own floor is below \`${MIN_OS_CURRENT}\`; see the \`wrapper-build-log-${PLATFORM}\` artifact"
  fi
elif [[ "$STATUS" == "upstream-breaking" ]]; then
  STATUS_LINE="🛑 **DRAFT - Microsoft marked this release \`[Breaking]\`.** Everything builds and the binding's own minimum OS version is unchanged, but read the upstream note above before merging: the break may be a support-policy change rather than anything visible in the artifact. Mark the PR ready once you have decided it is safe for consumers."
  BUILD_LINE="✅ Binding builds (\`dotnet build -c Release\`)"
  WRAPPER_LINE="✅ Wrapper compiles against the packed binding (\`${TFM}\`, wrapper csproj untouched)"
else
  STATUS_LINE="🛑 **DRAFT - the wrapper does not compile against this binding.** The native API changed in a way the wrapper depends on; that is a wrapper change for a human, not something to merge as-is."
  BUILD_LINE="✅ Binding builds"
  WRAPPER_LINE="❌ Wrapper does NOT compile against it (\`${TFM}\`) - see the \`wrapper-build-log-${PLATFORM}\` artifact on the run"
fi

if [[ -n "$CHANGELOG_EXCERPT" ]]; then
  EXCERPT_BLOCK="$CHANGELOG_EXCERPT"
elif [[ "$PLATFORM" == "ios" ]]; then
  EXCERPT_BLOCK="_No notes published yet - neither a \`microsoft/clarity-apps\` release nor Microsoft Learn has an entry for this version._"
else
  EXCERPT_BLOCK="_Not published on Microsoft Learn yet._"
fi

if [[ "$MIN_OS_RAISED" == "true" ]]; then
  MIN_OS_ROW="⚠️ raised \`${MIN_OS_PREVIOUS}\` → \`${MIN_OS_CURRENT}\` (required by the native SDK)"
elif [[ -n "$MIN_OS_CURRENT" ]]; then
  MIN_OS_ROW="\`${MIN_OS_CURRENT}\` (unchanged)"
else
  MIN_OS_ROW="unchanged"
fi

if [[ "$CLAUDE_FIXED" == "true" ]]; then
  FIX_BLOCK="🤖 **Claude Code repaired the binding sources** so they compile against ${TARGET}. Review those edits with the same care as a hand-written change."$'\n\n'
  if [[ -n "$FIX_SUMMARY_FILE" && -s "$FIX_SUMMARY_FILE" ]]; then
    FIX_BLOCK+="$(cat "$FIX_SUMMARY_FILE")"
  else
    FIX_BLOCK+="_(the repair step wrote no summary)_"
  fi
else
  FIX_BLOCK="No binding source changes were needed beyond the version bump."
fi

RUN_LINE=""
if [[ -n "$RUN_URL" ]]; then
  RUN_LINE="Workflow run (build logs are attached as artifacts): ${RUN_URL}"
fi

BODY=$(cat <<EOF
Binding-only bump produced by \`${WORKFLOW}\`. The wrapper is moved onto \`${BINDING_VERSION}\` in a separate step once it is live on nuget.org.

| | |
|---|---|
| Previous | \`${PREVIOUS}\` |
| Target | \`${TARGET}\` |
| Binding version | \`${BINDING_VERSION}\` (nuget.org shows it as \`${PUBLISHED_VERSION}\`) |
| Minimum ${OS_NAME} | ${MIN_OS_ROW} |
| Source | ${SOURCE_URL} |
| Changelog | ${CHANGELOG_URL} |

### Upstream changelog ${TARGET}
${EXCERPT_BLOCK}

### Verification
- ${BUILD_LINE}
- ${WRAPPER_LINE}

### Binding sources
${FIX_BLOCK}

${RUN_LINE}

### Status
${STATUS_LINE}
EOF
)

LABELS=(bump "$PLATFORM" dependencies)
if [[ "$CLAUDE_FIXED" == "true" ]]; then LABELS+=(claude-fixed); fi
if [[ "$STATUS" != "green" ]]; then LABELS+=("$STATUS"); fi

BODY_FILE=$(mktemp)
printf '%s\n' "$BODY" > "$BODY_FILE"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] git push --force origin HEAD:refs/heads/${BRANCH}"
  echo "[dry-run] PR '${TITLE}'  ${BRANCH} -> ${BASE_BRANCH}  status=${STATUS}  labels=${LABELS[*]}"
  echo "----- PR body -----"
  cat "$BODY_FILE"
  echo "-------------------"
  exit 0
fi

# --- 4. Push (force: a previous run may have left the branch behind) -----------
git push --force origin "HEAD:refs/heads/${BRANCH}"

# --- 5. Labels (idempotent) ---------------------------------------------------------
gh label create bump           --color 0E8A16 --description "Native Clarity SDK bump produced by TryBumpAndroid / TryBumpIOS" --force >/dev/null
gh label create claude-fixed   --color 5319E7 --description "Binding sources were repaired by Claude Code - review them" --force >/dev/null
gh label create binding-broken --color B60205 --description "The binding does not build against the new native SDK" --force >/dev/null
gh label create wrapper-broken --color B60205 --description "The wrapper does not compile against the new binding" --force >/dev/null
gh label create min-os-raised  --color D93F0B --description "The native SDK raised the minimum OS version - breaking for consumers" --force >/dev/null
gh label create upstream-breaking --color D93F0B --description "Microsoft marked this native SDK release [Breaking]" --force >/dev/null

LABEL_ARGS=()
for label in "${LABELS[@]}"; do LABEL_ARGS+=(--label "$label"); done
ADD_LABEL_ARGS=()
for label in "${LABELS[@]}"; do ADD_LABEL_ARGS+=(--add-label "$label"); done

# --- 6. Create or refresh the PR -----------------------------------------------------
NUM=$(gh pr list --head "$BRANCH" --base "$BASE_BRANCH" --state open --json number --jq '.[0].number // empty')
if [[ -z "$NUM" ]]; then
  # macOS runners ship bash 3.2, where expanding an EMPTY array under `set -u` is an
  # "unbound variable" error; the ${arr[@]+"${arr[@]}"} idiom is safe on every bash.
  DRAFT_ARGS=()
  if [[ "$STATUS" != "green" ]]; then DRAFT_ARGS=(--draft); fi
  URL=$(gh pr create --base "$BASE_BRANCH" --head "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE" \
    "${LABEL_ARGS[@]}" ${DRAFT_ARGS[@]+"${DRAFT_ARGS[@]}"})
  NUM=$(printf '%s' "$URL" | grep -oE '[0-9]+$')
  echo "==> opened PR #$NUM"
else
  echo "==> refreshing existing PR #$NUM"
  gh pr edit "$NUM" --title "$TITLE" --body-file "$BODY_FILE" \
    --remove-label claude-fixed --remove-label binding-broken --remove-label wrapper-broken \
    --remove-label min-os-raised --remove-label upstream-breaking >/dev/null || true
  gh pr edit "$NUM" "${ADD_LABEL_ARGS[@]}" >/dev/null
  if [[ "$STATUS" == "green" ]]; then
    gh pr ready "$NUM" || true
  else
    gh pr ready "$NUM" --undo || true
  fi
  URL=$(gh pr view "$NUM" --json url --jq .url)
fi

if [[ -z "$NUM" ]]; then
  echo "ERROR: could not determine a PR number for $BRANCH" >&2
  exit 1
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "pr_number=${NUM}"
    echo "pr_url=${URL}"
    echo "branch=${BRANCH}"
  } >> "$GITHUB_OUTPUT"
fi
echo "==> PR #${NUM} ${URL} (${STATUS})"
