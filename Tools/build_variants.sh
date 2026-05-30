#!/usr/bin/env bash
# Telegram Android build helper
#
# Purpose:
# - Provide one place to build common APK/AAB variants across app modules.
# - Make architecture selection explicit (fat vs ABI-limited).
# - Keep commands reproducible for local CI/manual release workflows.
#
# Usage examples:
#   ./Tools/build_variants.sh list
#   ./Tools/build_variants.sh app-release-apk
#   ./Tools/build_variants.sh app-release-aab
#   ./Tools/build_variants.sh app-release-apk --abi x86_64
#   ./Tools/build_variants.sh standalone-release-apk --abi x86_64
#   ./Tools/build_variants.sh huawei-release-apk --abi x86_64
#   ./Tools/build_variants.sh all-known-working --abi x86_64
#
# Notes on ABIs:
# - Default behavior builds all ABIs configured in each flavor.
# - Optional ABI-limited runs are still available with:
#     -Pandroid.injected.build.abi=<abi>
#   Use this only when debugging host/toolchain issues.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GRADLE="./gradlew"
COMMON_FLAGS=(--stacktrace)

TASK="${1:-list}"
shift || true

ABI=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --abi)
      ABI="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

GRADLE_ABI_ARGS=()
if [[ -n "$ABI" ]]; then
  GRADLE_ABI_ARGS+=("-Pandroid.injected.build.abi=$ABI")
fi

run_gradle() {
  local task_name="$1"
  echo "==> Running: $GRADLE ${GRADLE_ABI_ARGS[*]:-} $task_name ${COMMON_FLAGS[*]}"
  "$GRADLE" "${GRADLE_ABI_ARGS[@]}" "$task_name" "${COMMON_FLAGS[@]}"
}

print_list() {
  cat <<'LIST'
Available targets:
  list
  app-debug-apk
  app-release-apk
  app-release-aab
  app-release-aab-sdk23
  standalone-release-apk
  standalone-release-aab
  huawei-release-apk
  huawei-release-aab
  all-main-fat
  all-known-working

Target details:
  app-debug-apk           -> :TMessagesProj_App:assembleAfatDebug
  app-release-apk         -> :TMessagesProj_App:assembleAfatRelease
  app-release-aab         -> :TMessagesProj_App:bundleBundleAfatRelease
  app-release-aab-sdk23   -> :TMessagesProj_App:bundleBundleAfat_SDK23Release
  standalone-release-apk  -> :TMessagesProj_AppStandalone:assembleAfatStandalone
  standalone-release-aab  -> :TMessagesProj_AppStandalone:bundleAfatRelease
  huawei-release-apk      -> :TMessagesProj_AppHuawei:assembleAfatRelease
  huawei-release-aab      -> :TMessagesProj_AppHuawei:bundleAfatRelease

Batch targets:
  all-main-fat:
    Attempts full-fat release builds for App/Standalone/Huawei.
    Recommended only when native toolchain supports all ABIs.

  all-known-working:
    Builds the variants that are known to pass on this host when ABI is restricted.
    Use: ./Tools/build_variants.sh all-known-working --abi x86_64
LIST
}

case "$TASK" in
  list)
    print_list
    ;;
  app-debug-apk)
    run_gradle ":TMessagesProj_App:assembleAfatDebug"
    ;;
  app-release-apk)
    run_gradle ":TMessagesProj_App:assembleAfatRelease"
    ;;
  app-release-aab)
    run_gradle ":TMessagesProj_App:bundleBundleAfatRelease"
    ;;
  app-release-aab-sdk23)
    run_gradle ":TMessagesProj_App:bundleBundleAfat_SDK23Release"
    ;;
  standalone-release-apk)
    run_gradle ":TMessagesProj_AppStandalone:assembleAfatStandalone"
    ;;
  standalone-release-aab)
    run_gradle ":TMessagesProj_AppStandalone:bundleAfatRelease"
    ;;
  huawei-release-apk)
    run_gradle ":TMessagesProj_AppHuawei:assembleAfatRelease"
    ;;
  huawei-release-aab)
    run_gradle ":TMessagesProj_AppHuawei:bundleAfatRelease"
    ;;
  all-main-fat)
    run_gradle ":TMessagesProj_App:assembleAfatRelease"
    run_gradle ":TMessagesProj_App:bundleBundleAfatRelease"
    run_gradle ":TMessagesProj_AppStandalone:assembleAfatStandalone"
    run_gradle ":TMessagesProj_AppHuawei:assembleAfatRelease"
    ;;
  all-known-working)
    if [[ -z "$ABI" ]]; then
      echo "all-known-working requires --abi (example: --abi x86_64)" >&2
      exit 2
    fi
    run_gradle ":TMessagesProj_App:assembleAfatRelease"
    run_gradle ":TMessagesProj_App:bundleBundleAfat_SDK23Release"
    run_gradle ":TMessagesProj_App:bundleBundleAfatRelease"
    run_gradle ":TMessagesProj_AppStandalone:assembleAfatStandalone"
    run_gradle ":TMessagesProj_AppHuawei:assembleAfatRelease"
    ;;
  *)
    echo "Unknown target: $TASK" >&2
    print_list
    exit 2
    ;;
esac

echo
echo "Build command completed: $TASK"
echo "Tip: locate canonical artifacts under each module's build/outputs."
