#!/usr/bin/env bash
set -euo pipefail

# Build: Huawei app APK release variant (all device ABIs configured in project).
# Output export root:
#   build_exports/TMessagesProj_AppHuawei_assembleAfatRelease_<timestamp>/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_build_variant_common.sh"

run_variant_build \
  "$ROOT_DIR/TMessagesProj_AppHuawei" \
  ":TMessagesProj_AppHuawei:assembleAfatRelease" \
  "TMessagesProj_AppHuawei_assembleAfatRelease" \
  "afatRelease" \
  "apk" \
  "apk/afat/release"
