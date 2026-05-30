#!/usr/bin/env bash
set -euo pipefail

# Build: Standalone app APK release variant (all device ABIs configured in project).
# Output export root:
#   build_exports/TMessagesProj_AppStandalone_assembleAfatStandalone_<timestamp>/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_build_variant_common.sh"

run_variant_build \
  "$ROOT_DIR/TMessagesProj_AppStandalone" \
  ":TMessagesProj_AppStandalone:assembleAfatStandalone" \
  "TMessagesProj_AppStandalone_assembleAfatStandalone" \
  "afatStandalone" \
  "apk" \
  "apk/afat/standalone"
