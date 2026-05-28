#!/usr/bin/env bash
set -euo pipefail

# Build: App bundle, SDK23 release flavor (all device ABIs configured in project).
# Output export root:
#   build_exports/TMessagesProj_App_bundleBundleAfat_SDK23Release_<timestamp>/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_build_variant_common.sh"

run_variant_build \
  "$ROOT_DIR/TMessagesProj_App" \
  ":TMessagesProj_App:bundleBundleAfat_SDK23Release" \
  "TMessagesProj_App_bundleBundleAfat_SDK23Release" \
  "bundleAfat_SDK23Release" \
  "bundle" \
  "bundle/bundleAfat_SDK23Release"
