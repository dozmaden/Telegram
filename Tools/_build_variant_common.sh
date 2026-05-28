#!/usr/bin/env bash
set -euo pipefail

# Shared implementation for Telegram variant build/export scripts.
# This helper keeps all scripts consistent and reduces copy/paste mistakes.
#
# Usage:
#   source "_build_variant_common.sh"
#   run_variant_build \
#     "<module_dir>" \
#     "<gradle_task>" \
#     "<build_id>" \
#     "<variant_dir>" \
#     "<artifact_kind>" \
#     "<artifact_rel_path>"
#
# artifact_kind:
#   apk | bundle
# artifact_rel_path examples:
#   apk/afat/release
#   apk/afat/standalone
#   bundle/bundleAfatRelease

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP="${TIMESTAMP:-$(date '+%Y%m%d-%H%M%S')}"

_copy_if_exists() {
  local src="$1"
  local dst_rel="$2"
  local dest_dir="$3"
  if [[ -e "$src" ]]; then
    mkdir -p "$dest_dir/$dst_rel"
    cp -R "$src" "$dest_dir/$dst_rel/"
  fi
}

_require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "ERROR: required file not found: $path" >&2
    return 1
  fi
}

_validate_export() {
  local dest_dir="$1"
  local artifact_kind="$2"

  case "$artifact_kind" in
    apk)
      if ! find "$dest_dir/outputs/apk" -type f -name "*.apk" >/dev/null 2>&1; then
        echo "ERROR: no APK exported under $dest_dir/outputs/apk" >&2
        return 1
      fi
      ;;
    bundle)
      if ! find "$dest_dir/outputs/bundle" -type f -name "*.aab" >/dev/null 2>&1; then
        echo "ERROR: no AAB exported under $dest_dir/outputs/bundle" >&2
        return 1
      fi
      ;;
    *)
      echo "ERROR: unknown artifact kind: $artifact_kind" >&2
      return 1
      ;;
  esac
}

run_variant_build() {
  if [[ $# -ne 6 ]]; then
    echo "ERROR: run_variant_build expects 6 arguments, got $#" >&2
    return 2
  fi

  local module_dir="$1"
  local task="$2"
  local build_id="$3"
  local variant_dir="$4"
  local artifact_kind="$5"
  local artifact_rel_path="$6"
  local dest_dir="$ROOT_DIR/build_exports/${build_id}_${TIMESTAMP}"
  local gradlew="$ROOT_DIR/gradlew"

  _require_file "$gradlew"

  mkdir -p "$dest_dir"
  cd "$ROOT_DIR"

  echo "==> Running $task"
  "$gradlew" "$task" --stacktrace

  _copy_if_exists "$module_dir/build/outputs/$artifact_rel_path" "outputs/$artifact_kind" "$dest_dir"
  _copy_if_exists "$module_dir/build/outputs/mapping/$variant_dir" "outputs/mapping" "$dest_dir"
  _copy_if_exists "$module_dir/build/outputs/native-debug-symbols/$variant_dir" "outputs/native-debug-symbols" "$dest_dir"
  _copy_if_exists "$module_dir/build/outputs/sdk-dependencies/$variant_dir" "outputs/sdk-dependencies" "$dest_dir"
  _copy_if_exists "$module_dir/build/outputs/logs" "outputs" "$dest_dir"

  _validate_export "$dest_dir" "$artifact_kind"

  cat > "$dest_dir/BUILD_INFO.txt" <<INFO
task=$task
module=$module_dir
variant_dir=$variant_dir
artifact_kind=$artifact_kind
artifact_rel_path=$artifact_rel_path
timestamp=$TIMESTAMP
artifact_dir=$dest_dir
INFO

  echo "==> Build export ready: $dest_dir"
}
