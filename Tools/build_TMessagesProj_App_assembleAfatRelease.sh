#!/usr/bin/env bash
set -euo pipefail

# Build: Main app APK release variant (all device ABIs configured in project).
# Output export root:
#   build_exports/TMessagesProj_App_assembleAfatRelease_<timestamp>/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_build_variant_common.sh"

run_variant_build \
  "$ROOT_DIR/TMessagesProj_App" \
  ":TMessagesProj_App:assembleAfatRelease" \
  "TMessagesProj_App_assembleAfatRelease" \
  "afatRelease" \
  "apk" \
  "apk/afat/release"
