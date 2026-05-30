#!/usr/bin/env bash
set -euo pipefail

# Rebuild FFmpeg Android static archives used by Telegram native build.
#
# Why this script exists:
# - The checked-in arm64 archive can fail to link on modern NDK/LLD with:
#     relocation R_AARCH64_* ... recompile with -fPIC
# - This script rebuilds FFmpeg 4.4.3 with modern NDK clang and applies
#   upstream PIC relocation fixes for AArch64 FFT assembly.
#
# What it updates:
# - TMessagesProj/jni/ffmpeg/<abi>/lib{avcodec,avformat,avutil,avresample,swresample,swscale}.a
#
# Default ABIs:
# - arm64-v8a, armeabi-v7a
#
# Usage:
#   ./Tools/rebuild_ffmpeg_android.sh
#   ./Tools/rebuild_ffmpeg_android.sh --abis arm64-v8a
#   ANDROID_NDK_ROOT=~/Library/Android/sdk/ndk/24.0.8215888 ./Tools/rebuild_ffmpeg_android.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FFMPEG_LIB_DIR="$ROOT_DIR/TMessagesProj/jni/ffmpeg"

NDK_DEFAULT="$HOME/Library/Android/sdk/ndk/24.0.8215888"
NDK_ROOT="${ANDROID_NDK_ROOT:-${ANDROID_NDK_HOME:-$NDK_DEFAULT}}"
TOOLCHAIN="$NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64"

ABIS="arm64-v8a,armeabi-v7a"
JOBS="${JOBS:-$(sysctl -n hw.logicalcpu 2>/dev/null || echo 8)}"

WORK_DIR="$ROOT_DIR/.build/ffmpeg-android"
SRC_ARCHIVE="$WORK_DIR/ffmpeg-4.4.3.tar.xz"
SRC_DIR="$WORK_DIR/ffmpeg-4.4.3"
INSTALL_DIR="$WORK_DIR/install"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --abis)
      ABIS="${2:-}"
      shift 2
      ;;
    --help|-h)
      sed -n '1,80p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$FFMPEG_LIB_DIR" ]]; then
  echo "Missing directory: $FFMPEG_LIB_DIR" >&2
  exit 1
fi

if [[ ! -d "$TOOLCHAIN/bin" ]]; then
  echo "NDK LLVM toolchain not found at: $TOOLCHAIN/bin" >&2
  echo "Set ANDROID_NDK_ROOT to your installed NDK path." >&2
  exit 1
fi

mkdir -p "$WORK_DIR"

if [[ ! -f "$SRC_ARCHIVE" ]]; then
  echo "Downloading FFmpeg 4.4.3 source archive..."
  curl -L "https://ffmpeg.org/releases/ffmpeg-4.4.3.tar.xz" -o "$SRC_ARCHIVE"
fi

rm -rf "$SRC_DIR" "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xf "$SRC_ARCHIVE" -C "$WORK_DIR"

echo "Applying AArch64 PIC fix (movrelx via GOT for extern symbols)..."
ASM_FILE="$SRC_DIR/libavutil/aarch64/asm.S"
if ! grep -q '^\.macro  movrelx rd, val, offset=0$' "$ASM_FILE"; then
  perl -0pi -e 's/\.endm\n\n#define GLUE\(a, b\) a ## b/.endm\n\n.macro  movrelx rd, val, offset=0\n#if CONFIG_PIC\n#if defined(__APPLE__)\n        adrp            \\rd, \\val\\@GOTPAGE\n        ldr             \\rd, [\\rd, \\val\\@GOTPAGEOFF]\n#else\n        adrp            \\rd, :got:\\val\n        ldr             \\rd, [\\rd, :got_lo12:\\val]\n#endif\n    .if \\offset > 0\n        add             \\rd, \\rd, \\offset\n    .elseif \\offset < 0\n        sub             \\rd, \\rd, -(\\offset)\n    .endif\n#else\n        ldr             \\rd, =\\val+\\offset\n#endif\n.endm\n\n#define GLUE(a, b) a ## b/s' "$ASM_FILE"
fi

perl -0pi -e 's/movrel          x4,  X\(ff_cos_\\n\)/movrelx         x4,  X(ff_cos_\\n)/g; s/movrel          x14, X\(ff_cos_16\)/movrelx         x14, X(ff_cos_16)/g;' "$SRC_DIR/libavcodec/aarch64/fft_neon.S"
perl -0pi -e 's/movrel          x7, X\(ff_sbr_noise_table\)/movrelx         x7, X(ff_sbr_noise_table)/g;' "$SRC_DIR/libavcodec/aarch64/sbrdsp_neon.S"
perl -0pi -e 's/movrel          x6,  X\(ff_vp9_subpel_filters\), 256\*\\offset/movrelx         x6,  X(ff_vp9_subpel_filters), 256\*\\offset/g; s/movrel          x5,  X\(ff_vp9_subpel_filters\), 256\*\\offset/movrelx         x5,  X(ff_vp9_subpel_filters), 256\*\\offset/g;' "$SRC_DIR/libavcodec/aarch64/vp9mc_16bpp_neon.S"
perl -0pi -e 's/movrel          x6,  X\(ff_vp9_subpel_filters\), 256\*\\offset/movrelx         x6,  X(ff_vp9_subpel_filters), 256\*\\offset/g; s/movrel          x5,  X\(ff_vp9_subpel_filters\), 256\*\\offset/movrelx         x5,  X(ff_vp9_subpel_filters), 256\*\\offset/g;' "$SRC_DIR/libavcodec/aarch64/vp9mc_neon.S"
perl -0pi -e 's/function ff_prefetch_aarch64, export=1\n/function ff_prefetch_aarch64, export=1\n1:\n/g; s/b\.gt            X\(ff_prefetch_aarch64\)/b.gt            1b/g;' "$SRC_DIR/libavcodec/aarch64/videodsp.S"
perl -0pi -e 's/function swri_oldapi_conv_flt_to_s16_neon, export=1\n/function swri_oldapi_conv_flt_to_s16_neon, export=1\noldapi_conv_flt_to_s16_neon:\n/g; s/function swri_oldapi_conv_fltp_to_s16_2ch_neon, export=1\n/function swri_oldapi_conv_fltp_to_s16_2ch_neon, export=1\noldapi_conv_fltp_to_s16_2ch_neon:\n/g; s/b\.eq            X\(swri_oldapi_conv_fltp_to_s16_2ch_neon\)/b.eq            oldapi_conv_fltp_to_s16_2ch_neon/g; s/b               X\(swri_oldapi_conv_flt_to_s16_neon\)/b               oldapi_conv_flt_to_s16_neon/g;' "$SRC_DIR/libswresample/aarch64/audio_convert_neon.S"

common_config=(
  --target-os=android
  --enable-cross-compile
  --enable-stripping
  --enable-pic
  --disable-shared
  --enable-static
  --enable-asm
  --enable-inline-asm
  --enable-version3
  --enable-gpl
  --disable-doc
  --disable-avx
  --disable-everything
  --disable-network
  --disable-zlib
  --disable-avfilter
  --disable-avdevice
  --disable-postproc
  --disable-debug
  --disable-programs
  --enable-libvpx
  --enable-decoder=libvpx_vp9
  --enable-encoder=libvpx_vp9
  --enable-muxer=matroska
  --enable-bsf=vp9_superframe
  --enable-bsf=vp9_raw_reorder
  --enable-runtime-cpudetect
  --enable-pthreads
  --enable-avresample
  --enable-swscale
  --enable-protocol=file
  --enable-decoder=h264
  --enable-decoder=h265
  --enable-decoder=mpeg4
  --enable-decoder=mjpeg
  --enable-decoder=gif
  --enable-decoder=alac
  --enable-decoder=opus
  --enable-decoder=mp3
  --enable-decoder=aac
  --enable-demuxer=mov
  --enable-demuxer=gif
  --enable-demuxer=ogg
  --enable-demuxer=matroska
  --enable-demuxer=mp3
  --enable-demuxer=aac
  --enable-hwaccels
)

build_abi() {
  local abi="$1"
  local api arch cc cxx cross_prefix extra_cflags
  local dest="$FFMPEG_LIB_DIR/$abi"
  local prefix="$INSTALL_DIR/$abi"

  case "$abi" in
    arm64-v8a)
      api=21
      arch=aarch64
      cc="$TOOLCHAIN/bin/aarch64-linux-android${api}-clang"
      cxx="$TOOLCHAIN/bin/aarch64-linux-android${api}-clang++"
      cross_prefix="$TOOLCHAIN/bin/aarch64-linux-android-"
      extra_cflags="-fPIC"
      ;;
    armeabi-v7a)
      # NDK r24 no longer ships armv7 clang wrappers below API 19.
      api=19
      arch=arm
      cc="$TOOLCHAIN/bin/armv7a-linux-androideabi${api}-clang"
      cxx="$TOOLCHAIN/bin/armv7a-linux-androideabi${api}-clang++"
      cross_prefix="$TOOLCHAIN/bin/arm-linux-androideabi-"
      extra_cflags="-fPIC -mthumb"
      ;;
    *)
      echo "Unsupported ABI: $abi" >&2
      return 2
      ;;
  esac

  echo
  echo "=== Building FFmpeg for $abi (API $api) ==="
  mkdir -p "$prefix"
  (cd "$SRC_DIR" && make distclean >/dev/null 2>&1 || true)

  local local_config=("${common_config[@]}")
  local local_extra_libs="-lvpx -lm -lz"

  if [[ "${ENABLE_DAV1D:-0}" == "1" ]]; then
    local_config+=(--enable-libdav1d)
    local_extra_libs="-lvpx -ldav1d -lm -lz"
  fi

  (
    cd "$SRC_DIR"
    ./configure \
      --prefix="$prefix" \
      --arch="$arch" \
      --cc="$cc" \
      --cxx="$cxx" \
      --ar="$TOOLCHAIN/bin/llvm-ar" \
      --nm="$TOOLCHAIN/bin/llvm-nm" \
      --ranlib="$TOOLCHAIN/bin/llvm-ranlib" \
      --strip="$TOOLCHAIN/bin/llvm-strip" \
      --cross-prefix="$cross_prefix" \
      --extra-cflags="-I$FFMPEG_LIB_DIR/include $extra_cflags" \
      --extra-ldflags="-L$FFMPEG_LIB_DIR/$abi" \
      --extra-libs="$local_extra_libs" \
      "${local_config[@]}"
    make -j"$JOBS"
    make install
  )

  echo "Copying rebuilt archives into $dest"
  cp "$prefix/lib/libavcodec.a" "$dest/libavcodec.a"
  cp "$prefix/lib/libavformat.a" "$dest/libavformat.a"
  cp "$prefix/lib/libavutil.a" "$dest/libavutil.a"
  cp "$prefix/lib/libavresample.a" "$dest/libavresample.a"
  cp "$prefix/lib/libswresample.a" "$dest/libswresample.a"
  cp "$prefix/lib/libswscale.a" "$dest/libswscale.a"
}

IFS=',' read -r -a ABI_LIST <<< "$ABIS"
for abi in "${ABI_LIST[@]}"; do
  build_abi "$abi"
done

echo
echo "FFmpeg rebuild complete for: $ABIS"
