#!/usr/bin/env bash
set -euo pipefail

# Build and verify reproducible obfuscated TMessagesProj_App release APKs.
#
# Supported variants:
#   afatObfuscatedRelease
#   bundleAfatObfuscatedRelease
#   bundleAfat_SDK23ObfuscatedRelease
#
# The Gradle flavors define native ABIs. Do not pass an ABI property here.
#
# Flow:
#   1. Build once without -applymapping. Save the APK for inspection, but use
#      only its mapping.txt as the seed mapping.
#   2. Build with -applymapping <seed mapping.txt>. Save APK and mapping.
#   3. Build with -applymapping <seed mapping.txt> again from a clean build.
#   4. Deterministically sign both apply-mapping APKs and compare SHA-256.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP="${TIMESTAMP:-$(date '+%Y%m%d-%H%M%S')}"

VARIANT="${1:-afatObfuscatedRelease}"
shift || true
if [[ $# -gt 0 ]]; then
  echo "ERROR: unexpected argument(s): $*" >&2
  exit 2
fi

case "$VARIANT" in
  afatObfuscatedRelease)
    FLAVOR="afatObfuscated"
    TASK=":TMessagesProj_App:assembleAfatObfuscatedRelease"
    ;;
  bundleAfatObfuscatedRelease)
    FLAVOR="bundleAfatObfuscated"
    TASK=":TMessagesProj_App:assembleBundleAfatObfuscatedRelease"
    ;;
  bundleAfat_SDK23ObfuscatedRelease)
    FLAVOR="bundleAfat_SDK23Obfuscated"
    TASK=":TMessagesProj_App:assembleBundleAfat_SDK23ObfuscatedRelease"
    ;;
  list|--list|-h|--help)
    cat <<'LIST'
Usage:
  Tools/build_TMessagesProj_App_obfuscated_reproducible.sh [variant]

Supported variants:
  afatObfuscatedRelease
  bundleAfatObfuscatedRelease
  bundleAfat_SDK23ObfuscatedRelease
LIST
    exit 0
    ;;
  *)
    echo "ERROR: unsupported obfuscated reproducible variant: $VARIANT" >&2
    echo "Run with --list to see supported variants." >&2
    exit 2
    ;;
esac

GRADLEW="$ROOT_DIR/gradlew"
BUILD_ID="TMessagesProj_App_${VARIANT}_reproducible"
MODULE_DIR="$ROOT_DIR/TMessagesProj_App"
APK_PATH="$MODULE_DIR/build/outputs/apk/$FLAVOR/release/app.apk"
MAPPING_DIR="$MODULE_DIR/build/outputs/mapping/$VARIANT"
MAPPING_PATH="$MAPPING_DIR/mapping.txt"
DEST_DIR="$ROOT_DIR/build_exports/${BUILD_ID}_${TIMESTAMP}"

APKSIGNER="${APKSIGNER:-$ROOT_DIR/../Android/Sdk/build-tools/35.0.0/apksigner}"
if [[ ! -x "$APKSIGNER" ]]; then
  APKSIGNER="${ANDROID_HOME:-$HOME/Library/Android/sdk}/build-tools/35.0.0/apksigner"
fi

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "ERROR: required file not found: $path" >&2
    exit 1
  fi
}

read_property() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$ROOT_DIR/local.properties"
}

require_file "$GRADLEW"
require_file "$APKSIGNER"
require_file "$ROOT_DIR/local.properties"
require_file "$ROOT_DIR/TMessagesProj/config/release.keystore"

KEYSTORE="$ROOT_DIR/TMessagesProj/config/release.keystore"
KEY_ALIAS="${RELEASE_KEY_ALIAS:-$(read_property RELEASE_KEY_ALIAS)}"
STORE_PASS="${RELEASE_STORE_PASSWORD:-$(read_property RELEASE_STORE_PASSWORD)}"
KEY_PASS="${RELEASE_KEY_PASSWORD:-$(read_property RELEASE_KEY_PASSWORD)}"
SIGNING_MIN_SDK="${REPRO_SIGNING_MIN_SDK:-17}"

run_gradle() {
  echo "==> ./gradlew clean $TASK --stacktrace $*"
  (cd "$ROOT_DIR" && "$GRADLEW" clean "$TASK" --stacktrace "$@")
}

copy_mapping_dir() {
  local output_dir="$1"
  mkdir -p "$output_dir"
  require_file "$MAPPING_PATH"
  cp "$MAPPING_PATH" "$output_dir/mapping.txt"
  cp "$MAPPING_DIR/configuration.txt" "$output_dir/configuration.txt" 2>/dev/null || true
  cp "$MAPPING_DIR/seeds.txt" "$output_dir/seeds.txt" 2>/dev/null || true
  cp "$MAPPING_DIR/usage.txt" "$output_dir/usage.txt" 2>/dev/null || true
}

sign_deterministically() {
  local input_apk="$1"
  local output_apk="$2"

  mkdir -p "$(dirname "$output_apk")"
  cp "$input_apk" "$output_apk"
  "$APKSIGNER" sign \
    --min-sdk-version "$SIGNING_MIN_SDK" \
    --v1-signing-enabled true \
    --v2-signing-enabled true \
    --v3-signing-enabled false \
    --ks "$KEYSTORE" \
    --ks-key-alias "$KEY_ALIAS" \
    --ks-pass "pass:$STORE_PASS" \
    --key-pass "pass:$KEY_PASS" \
    "$output_apk"
}

record_build() {
  local label="$1"
  local apk_dir="$DEST_DIR/outputs/apk/$label"
  local mapping_dir="$DEST_DIR/outputs/mapping/$label"
  local signed_apk="$apk_dir/app.apk"

  require_file "$APK_PATH"
  sign_deterministically "$APK_PATH" "$signed_apk"
  copy_mapping_dir "$mapping_dir"
  shasum -a 256 "$signed_apk" | awk '{ print $1 }'
}

mkdir -p "$DEST_DIR/outputs/apk" "$DEST_DIR/outputs/mapping"

echo "==> Variant: $VARIANT"
echo "==> Seed build: no -applymapping"
run_gradle
SEED_SHA="$(record_build "seed-no-applymapping")"
SEED_MAPPING="$DEST_DIR/outputs/mapping/seed-no-applymapping/mapping.txt"
require_file "$SEED_MAPPING"

echo "==> Apply-mapping build 1: $SEED_MAPPING"
run_gradle "-PR8ApplyMapping=$SEED_MAPPING"
APPLY1_SHA="$(record_build "applymapping-1")"

echo "==> Apply-mapping build 2: $SEED_MAPPING"
run_gradle "-PR8ApplyMapping=$SEED_MAPPING"
APPLY2_SHA="$(record_build "applymapping-2")"

RESULT="MISMATCH"
if [[ "$APPLY1_SHA" == "$APPLY2_SHA" ]]; then
  RESULT="MATCH"
fi

RESULT_FILE="$DEST_DIR/outputs/REPRODUCIBILITY_RESULT.txt"
cat > "$RESULT_FILE" <<INFO
task=$TASK
variant=$VARIANT
flavor=$FLAVOR
seed_apk=$DEST_DIR/outputs/apk/seed-no-applymapping/app.apk
seed_mapping=$SEED_MAPPING
seed_sha256=$SEED_SHA
applymapping_1_apk=$DEST_DIR/outputs/apk/applymapping-1/app.apk
applymapping_1_mapping=$DEST_DIR/outputs/mapping/applymapping-1/mapping.txt
applymapping_1_sha256=$APPLY1_SHA
applymapping_2_apk=$DEST_DIR/outputs/apk/applymapping-2/app.apk
applymapping_2_mapping=$DEST_DIR/outputs/mapping/applymapping-2/mapping.txt
applymapping_2_sha256=$APPLY2_SHA
result=$RESULT
signing_min_sdk=$SIGNING_MIN_SDK
INFO

echo "==> Seed APK SHA-256:           $SEED_SHA"
echo "==> Apply-mapping #1 SHA-256:  $APPLY1_SHA"
echo "==> Apply-mapping #2 SHA-256:  $APPLY2_SHA"
echo "==> Reproducibility result:    $RESULT"
echo "==> Result file:               $RESULT_FILE"

if [[ "$RESULT" != "MATCH" ]]; then
  exit 1
fi
