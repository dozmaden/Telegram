#!/usr/bin/env bash
# Telegram Android build helper
#
# Purpose:
# - Provide one place to build common APK/AAB variants across app modules.
# - Use the ABI set configured in Gradle for each module/flavor.
# - Keep commands reproducible for local CI/manual release workflows.
#
# Usage examples:
#   ./Tools/build_variants.sh list
#   ./Tools/build_variants.sh app-release-apk
#   ./Tools/build_variants.sh app-obfuscated-release-apk
#   ./Tools/build_variants.sh app-bundle-obfuscated-release-apk
#   ./Tools/build_variants.sh app-release-aab
#
# Notes on ABIs:
# - These scripts do not pass -Pandroid.injected.build.abi.
# - Change ABI coverage in build.gradle, not through script parameters.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GRADLE="./gradlew"
COMMON_FLAGS=(--stacktrace)

TASK="${1:-list}"
shift || true

if [[ $# -gt 0 ]]; then
  echo "Unknown argument(s): $*" >&2
  echo "ABI selection is configured in build.gradle; this script does not accept ABI parameters." >&2
  exit 2
fi

run_gradle() {
  local task_name="$1"
  echo "==> Running: $GRADLE $task_name ${COMMON_FLAGS[*]}"
  "$GRADLE" "$task_name" "${COMMON_FLAGS[@]}"
}

print_list() {
  cat <<'LIST'
Available targets:
  list
  app-debug-apk
  app-release-apk
  app-obfuscated-release-apk
  app-bundle-obfuscated-release-apk
  app-bundle-sdk23-obfuscated-release-apk
  app-release-aab
  app-obfuscated-release-aab
  app-release-aab-sdk23
  app-obfuscated-release-aab-sdk23
  standalone-release-apk
  standalone-release-aab
  huawei-release-apk
  huawei-release-aab
  all-main-fat
  all-known-working

Target details:
  app-debug-apk           -> :TMessagesProj_App:assembleAfatDebug
  app-release-apk         -> :TMessagesProj_App:assembleAfatRelease
  app-obfuscated-release-apk -> :TMessagesProj_App:assembleAfatObfuscatedRelease
  app-bundle-obfuscated-release-apk -> :TMessagesProj_App:assembleBundleAfatObfuscatedRelease
  app-bundle-sdk23-obfuscated-release-apk -> :TMessagesProj_App:assembleBundleAfat_SDK23ObfuscatedRelease
  app-release-aab         -> :TMessagesProj_App:bundleBundleAfatRelease
  app-obfuscated-release-aab -> :TMessagesProj_App:bundleBundleAfatObfuscatedRelease
  app-release-aab-sdk23   -> :TMessagesProj_App:bundleBundleAfat_SDK23Release
  app-obfuscated-release-aab-sdk23 -> :TMessagesProj_App:bundleBundleAfat_SDK23ObfuscatedRelease
  standalone-release-apk  -> :TMessagesProj_AppStandalone:assembleAfatStandalone
  standalone-release-aab  -> :TMessagesProj_AppStandalone:bundleAfatRelease
  huawei-release-apk      -> :TMessagesProj_AppHuawei:assembleAfatRelease
  huawei-release-aab      -> :TMessagesProj_AppHuawei:bundleAfatRelease

Batch targets:
  all-main-fat:
    Attempts configured release builds for App/Standalone/Huawei.

  all-known-working:
    Builds the variants that are known to pass on this host with Gradle-defined ABIs.
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
  app-obfuscated-release-apk)
    run_gradle ":TMessagesProj_App:assembleAfatObfuscatedRelease"
    ;;
  app-bundle-obfuscated-release-apk)
    run_gradle ":TMessagesProj_App:assembleBundleAfatObfuscatedRelease"
    ;;
  app-bundle-sdk23-obfuscated-release-apk)
    run_gradle ":TMessagesProj_App:assembleBundleAfat_SDK23ObfuscatedRelease"
    ;;
  app-release-aab)
    run_gradle ":TMessagesProj_App:bundleBundleAfatRelease"
    ;;
  app-obfuscated-release-aab)
    run_gradle ":TMessagesProj_App:bundleBundleAfatObfuscatedRelease"
    ;;
  app-release-aab-sdk23)
    run_gradle ":TMessagesProj_App:bundleBundleAfat_SDK23Release"
    ;;
  app-obfuscated-release-aab-sdk23)
    run_gradle ":TMessagesProj_App:bundleBundleAfat_SDK23ObfuscatedRelease"
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
    run_gradle ":TMessagesProj_App:assembleAfatRelease"
    run_gradle ":TMessagesProj_App:assembleAfatObfuscatedRelease"
    run_gradle ":TMessagesProj_App:assembleBundleAfatObfuscatedRelease"
    run_gradle ":TMessagesProj_App:assembleBundleAfat_SDK23ObfuscatedRelease"
    run_gradle ":TMessagesProj_App:bundleBundleAfat_SDK23Release"
    run_gradle ":TMessagesProj_App:bundleBundleAfat_SDK23ObfuscatedRelease"
    run_gradle ":TMessagesProj_App:bundleBundleAfatRelease"
    run_gradle ":TMessagesProj_App:bundleBundleAfatObfuscatedRelease"
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
