#!/usr/bin/env bash
set -euo pipefail

# Build: App bundle, standard release flavor (all device ABIs configured in project).
# Output export root:
#   build_exports/TMessagesProj_App_bundleBundleAfatRelease_<timestamp>/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_build_variant_common.sh"

run_variant_build \
  "$ROOT_DIR/TMessagesProj_App" \
  ":TMessagesProj_App:bundleBundleAfatRelease" \
  "TMessagesProj_App_bundleBundleAfatRelease" \
  "bundleAfatRelease" \
  "bundle" \
  "bundle/bundleAfatRelease"
