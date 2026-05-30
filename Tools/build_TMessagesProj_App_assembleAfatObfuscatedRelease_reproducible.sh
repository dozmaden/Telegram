#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/build_TMessagesProj_App_obfuscated_reproducible.sh" afatObfuscatedRelease "$@"
