# Reproducible Release APK Builds

This project keeps the original release flavor behavior and adds separate
obfuscated release flavors for real R8 optimization and obfuscation.
Reproducible verification is intentionally wrapped in one script so verifiers
do not need to know R8 or APK signing internals.

The split is deliberate:

- `afatRelease`, `bundleAfatRelease`, and `bundleAfat_SDK23Release` use the
  original `TMessagesProj/proguard-rules.pro`, including its broad keeps plus
  `-dontoptimize` and `-dontobfuscate`.
- `afatObfuscatedRelease`, `bundleAfatObfuscatedRelease`, and
  `bundleAfat_SDK23ObfuscatedRelease` use
  `TMessagesProj/proguard-rules-obfuscated.pro`, which removes those global
  blockers and replaces broad keeps with narrower JNI, reflection, WebView,
  Parcelable, ML Kit, Huawei/GMS, ExoPlayer, and WebRTC rules.
- The native ABI set is defined in Gradle. The reproducible script does not pass
  ABI parameters; the current flavor configuration builds the 64-bit ABIs only.

## What `mapping.txt` Is

R8 performs several independent transformations:

- shrinking removes unreachable classes, methods, fields, and resources
- optimization rewrites code and can move, inline, merge, or simplify methods
- obfuscation renames remaining classes, methods, and fields
- dex layout decides which classes and code items are written into each
  `classes*.dex` file and where code/debug data is encoded
- ART profile rewriting rewrites `assets/dexopt/baseline.prof` so it points at
  the final obfuscated names

`mapping.txt` is mainly the name and source-position map from original program
symbols to obfuscated program symbols. A simplified example looks like this:

```text
org.telegram.example.LoginController -> a.b:
    int account -> a
    42:55:void startLogin(java.lang.String):100:113 -> b
org.telegram.example.NativeBridge -> a.c:
    void nativeStart(long) -> nativeStart
```

The first line says `LoginController` was renamed to `a.b`. The field line says
`account` was renamed to `a`. The method line says `startLogin(...)` was renamed
to `b`, and also records source-line mapping for retracing stack traces. The
native method keeps its name because JNI rules preserve native method names.

The important limit: `mapping.txt` is not a complete compiler cache. It does
not record every optimizer decision, every DEX layout decision, every debug-info
encoding choice, or every ART-profile rewrite detail. It is enough to force name
reuse, but it is not a promise that a build without `-applymapping` and a build
with `-applymapping` will have identical bytes.

## What `-applymapping` Does

`-applymapping <file>` gives R8 an existing mapping and asks it to reuse the
mapped names where those mappings still make sense for the current program. In
Gradle this project exposes the option as:

```bash
-Pr8ApplyMapping=/absolute/path/to/mapping.txt
```

The Gradle property generates a small ProGuard file containing:

```proguard
-applymapping /absolute/path/to/mapping.txt
```

Conceptually:

1. R8 reads the current source/classes and all keep rules.
2. R8 reads the supplied `mapping.txt`.
3. If a current class/member is present in the mapping and is still compatible,
   R8 reuses the old obfuscated name.
4. If a class/member is new, removed, changed, merged, inlined, or otherwise no
   longer maps cleanly, R8 may allocate or omit names as needed.
5. R8 still performs shrinking, optimization, DEX writing, resource/profile
   rewriting, and mapping output for this build.

Example:

```text
# Previous mapping
org.telegram.example.A -> x.a:
    void send() -> a
org.telegram.example.B -> x.b:
    void receive() -> a
```

If the next build still has both classes and both methods, `-applymapping`
tries to keep `A -> x.a`, `A.send -> a`, `B -> x.b`, and `B.receive -> a`.
If `A.send()` is inlined away, no method body needs to be emitted for that
method. If a new `C` class appears, R8 chooses a new obfuscated name for `C`.

So `-applymapping` constrains names. It does not turn R8 into a replay of the
previous no-mapping compilation.

## How The First APK Differs From The Second `-applymapping` APK

The tested sequence was:

1. Build once without `-applymapping`.
2. Save the generated `mapping.txt`.
3. Build again with `-Pr8ApplyMapping=<first mapping.txt>`.
4. Compare the APKs.

In this document the first APK means the seed no-mapping R8 output. Its mapping
is useful for the apply-mapping checks, but the seed APK itself is not the
reproducibility target. The reproducible target is the pair of clean
apply-mapping builds that both use that same seed mapping as input.

Those two APKs were not byte-identical. With R8 `8.8.34`, the observed APK sizes
were:

```text
first no-mapping APK:      49,071,273 bytes
second apply-mapping APK:  49,058,448 bytes
delta:                    -12,825 bytes
```

Only a small set of code/profile entries changed:

```text
classes.dex     7,261,612 -> 7,261,432 bytes  (-180)
classes2.dex      496,076 ->   496,076 bytes  (same)
classes3.dex    6,448,916 -> 6,451,064 bytes  (+2,148)
classes4.dex    8,596,380 -> 8,596,296 bytes  (-84)
classes5.dex    8,213,864 -> 8,215,068 bytes  (+1,204)
baseline.prof       3,087 ->     3,087 bytes  (same size, different hash)
```

Resource files, native libraries, and most APK entries were not the cause of the
first-vs-second R8 mismatch. The changed entries were DEX files and the ART
baseline profile.

`dexdump` showed that the class/method tables were largely the same, but code
item offsets, debug-position encoding, and line-position data changed. One small
example from `classes.dex`:

```text
# first no-mapping build
positions:
  0x0000 line=1
  0x0001 line=2
  0x0002 line=3
  ...
  0x000a line=11

# second apply-mapping build
positions:
  0x0000 line=1
```

The instruction bytes for that small method were the same, but the debug
position table was encoded differently and the method moved to a different DEX
data offset. Across a multidex APK, small debug/layout changes cascade into
different DEX checksums, different DEX hashes, and a different APK hash.

Several hypotheses were tested and rejected:

- Gradle/R8 worker count: using one worker did not make first and second match.
- R8 deterministic debugging mode: it did not make first and second match.
- Removing `SourceFile`/`LineNumberTable` from this project's keep attributes:
  it did not make first and second match.
- Disabling ART/startup profile toggles: it did not make first and second match.
- Updating from the AGP-bundled R8 to R8 `8.8.34`: useful for toolchain
  stability, but did not make first and second match.
- Removing line-range records from the mapping: it did not make first and
  second match.

The conclusion is that this is an R8 mode difference, not a source-code
difference and not just filesystem ordering or parallel scheduling. A no-mapping
R8 compilation and an apply-mapping R8 compilation are not guaranteed to be the
same compilation with only names preselected.

### Byte-Level Examples From The First And Second APKs

The first difference in `classes.dex` appears immediately after the DEX magic.
The first eight bytes are the fixed DEX magic/version. Bytes 8-11 are the DEX
Adler-32 checksum, bytes 12-31 are the SHA-1 signature, and later header fields
include the file and data-section sizes. These change as soon as any byte in the
DEX changes.

```text
# first no-mapping classes.dex
00000000: 64 65 78 0a 30 33 35 00 52 b4 b0 67 29 02 da c5
00000010: 5f e0 de 90 9a 76 eb 08 99 a4 ed 96 f3 e5 96 2b
00000020: ac cd 6e 00 70 00 00 00 78 56 34 12 00 00 00 00
00000030: 00 00 00 00 d0 cc 6e 00 54 86 00 00 70 00 00 00

# second apply-mapping classes.dex
00000000: 64 65 78 0a 30 33 35 00 ab aa de f9 27 0c d9 ab
00000010: 54 10 f5 1a d9 f7 47 7e b5 9b 98 43 61 52 b5 a3
00000020: f8 cc 6e 00 70 00 00 00 78 56 34 12 00 00 00 00
00000030: 00 00 00 00 1c cc 6e 00 54 86 00 00 70 00 00 00
```

The relevant header interpretation from `dexdump` was:

```text
first no-mapping classes.dex:
  file_size: 7261612
  data_size: 5715588

second apply-mapping classes.dex:
  file_size: 7261432
  data_size: 5715408
```

The file-size bytes also show the size change directly. DEX stores these values
little-endian:

```text
first bytes at 0x20:   ac cd 6e 00 = 0x006ecdac = 7,261,612 bytes
second bytes at 0x20:  f8 cc 6e 00 = 0x006eccf8 = 7,261,432 bytes

first bytes at 0x38:   d0 cc 6e 00 = 0x006eccd0 = 7,261,264 map/data boundary
second bytes at 0x38:  1c cc 6e 00 = 0x006ecc1c = 7,261,212 map/data boundary
```

That proves `classes.dex` is not just signed differently; the DEX payload itself
is different.

The raw byte comparison starts like this:

```text
cmp -l first/classes.dex apply/classes.dex | head
     9 122 253
    10 264 252
    11 260 336
    12 147 371
    13  51  47
    14   2  14
    15 332 331
    16 305 253
```

`cmp -l` prints one-based byte offset, first-file byte, second-file byte. The
numbers are octal. Offset 9 is the first DEX checksum byte, so this early diff
is expected once the DEX payload changes.

A more useful byte-level example is one small method body. In the no-mapping
build, the method starts at DEX data offset `0x179728`:

```text
# first no-mapping classes.dex at 0x179728
00179728: 04 00 03 00 00 00 00 00 64 e4 55 00 0b 00 00 00
00179738: 2e 00 01 02 3b 00 03 00 0f 02 2d 02 01 03 3d 02
00179748: 03 00 0f 03 0f 01 00 00
```

In the apply-mapping build, the same DEX offset contains different data:

```text
# second apply-mapping classes.dex at the old 0x179728 offset
00179728: 01 00 00 00 01 00 00 00 00 00 00 00 06 00 00 00
00179738: 22 00 b4 2b 70 10 7e cf 00 00 27 00 01 00 00 00
00179748: 01 00 00 00 00 00 00 00
```

The method still exists, but it moved. In the apply-mapping build it appears at
offset `0x1d8640`:

```text
# second apply-mapping classes.dex at the method's new offset 0x1d8640
001d8640: 04 00 03 00 00 00 00 00 d7 fb 55 00 0b 00 00 00
001d8650: 2e 00 01 02 3b 00 03 00 0f 02 2d 02 01 03 3d 02
001d8660: 03 00 0f 03 0f 01 00 00
```

The instruction stream is visibly the same from `2e 00 01 02 ... 0f 01`. The
surrounding code item metadata and debug-info offset differ:

```text
04 00        registers_size = 4
03 00        ins_size = 3
00 00        outs_size = 0
00 00        tries_size = 0
64 e4 55 00  first debug_info_off  = 0x0055e464
d7 fb 55 00  second debug_info_off = 0x0055fbd7
0b 00 00 00  insns_size = 11 code units
```

That matches the `dexdump` observation: the actual bytecode instructions can
stay the same while debug-position encoding, debug-info offsets, and data layout
move. Those offset changes are enough to change the DEX checksum, DEX SHA-1
signature, ZIP entry, APK signing input, and final APK hash.

The ART baseline profile also changed. The file size was the same, but bytes
inside the compressed profile changed:

```text
# first no-mapping assets/dexopt/baseline.prof
00000000: 70 72 6f 00 30 31 30 00 04 ca f3 00 00 fe 0b 00
00000010: 00 78 01 ed 9d 0b 70 54 57 19 c7 bf 73 77 37 d9
00000020: 3c 59 08 8f 10 a2 dd 58 1e 29 50 48 21 94 d4 b6

# second apply-mapping assets/dexopt/baseline.prof
00000000: 70 72 6f 00 30 31 30 00 04 ca f3 00 00 fe 0b 00
00000010: 00 78 01 ed 9d 0d 70 54 57 15 c7 cf 7d bb 9b 6c
00000020: 3e 08 0b 81 12 42 b4 1b cb 47 0a 14 52 08 25 b5
```

The header prefix is the same (`pro\0`, version `010`), but the compressed body
differs. The first baseline-profile byte mismatch was:

```text
cmp -l first/baseline.prof apply/baseline.prof | head
    22  13  15
    26  31  25
    28 277 317
    29 163 175
```

At the APK level, byte differences start very early because APK entries are ZIP
members and the first changed compressed entry changes local ZIP data:

```text
cmp -l first-app.apk applymapping-app.apk | head
   340  37 106
   341 254 161
   342 115  10
   343   5 271
```

That APK-level diff is not yet the final signing problem; it reflects changed
payload bytes. The signing problem was seen separately when two APKs had
identical DEX/profile contents but different bytes near the APK Signing Block.
This is why the investigation compared unpacked entries first, then signing.

### Why The Changed Bytes Matter

The first and second APKs are functionally very close, and much of the actual
bytecode instruction stream remains equivalent. But reproducibility is stricter
than functional equivalence. If a DEX debug-info offset, code-item order,
profile entry, compressed ZIP member, or signing block byte differs, the final
APK SHA-256 differs.

The first-vs-second mismatch is therefore real even though it is small:

- DEX headers differ because DEX payloads differ.
- DEX code-item offsets differ because data layout differs.
- Debug-position tables differ.
- `baseline.prof` differs because it is rewritten against the final obfuscated
  names and DEX/profile layout.
- The APK hash differs because those entries differ.

### Attempts To Make First And Second Match

Several possible causes were tested:

1. Parallelism or nondeterministic scheduling.
   - Tested Gradle `--max-workers=1`.
   - Tested `-Pandroid.r8.maxWorkers=1`.
   - Tested R8's internal `com.android.tools.r8.deterministicdebugging=true`.
   - Result: first and second still differed.

2. Source/line debug attributes.
   - Removed this project's explicit `SourceFile,LineNumberTable` keep
     attributes and forced fresh R8 runs.
   - Result: first and second still differed.

3. ART/startup profile rewriting.
   - Tested AGP profile-related toggles such as disabling R8 dex startup
     optimization and ART profile rewriting.
   - Result: first and second still differed.

4. R8 version.
   - AGP 8.6.1 bundles R8 8.6.27.
   - The build was tested with R8 8.8.34 pinned ahead of AGP.
   - Result: useful to pin a newer known R8 version, but first and second still
     differed.

5. Mapping line records.
   - Tested an apply mapping with line-range records removed.
   - Result: first and second still differed.

6. Signing.
   - Deterministic signing fixed repeatability after payloads matched.
   - Result: signing was a separate issue, not the reason first and second DEX
     payloads differed.

### Is First-To-Second Reproducibility Possible?

It is not proven impossible in principle, but it was not achievable with stock
AGP/R8 options while keeping real optimization and obfuscation enabled.

Ways it could become possible:

- R8 could change upstream so a no-mapping build and an apply-mapping build use
  byte-identical layout/debug/profile decisions when the mapping came from that
  exact no-mapping build.
- The project could use a custom patched R8 that forces that behavior.
- The build could disable enough optimization/profile/debug-layout behavior that
  the two modes happen to converge, but that works against this task's goal of
  enabling real optimization.

Containerization helps with environment drift: toolchain versions, paths,
locale, filesystem ordering, NDK output, and timestamps. It does not by itself
make the first and second builds match, because the observed difference is
inside R8's no-mapping versus apply-mapping compilation mode.

Therefore this project uses the fixed point that was observed to be stable:

```text
apply-mapping build output mapping
-> next apply-mapping build with that mapping
-> same DEX/profile payload
-> deterministic signing
-> same final APK hash
```

## Why The Second APK Matched The Third APK

The next sequence was:

1. Build with `-Pr8ApplyMapping=<seed mapping>`.
2. Save that build's output `mapping.txt`.
3. Build again with `-Pr8ApplyMapping=<mapping from step 2>`.
4. Compare DEX/profile contents.

The apply-mapping build and the next apply-mapping build had identical DEX and
profile contents:

```text
classes.dex       same SHA-256
classes2.dex      same SHA-256
classes3.dex      same SHA-256
classes4.dex      same SHA-256
classes5.dex      same SHA-256
baseline.prof     same SHA-256
```

This is the fixed point. Both builds enter the same R8 mode, both use a mapping
that was itself produced by an apply-mapping run, and R8 emits the same code and
profile payload.

The signed APK still differed until signing was fixed. That remaining difference
was in the APK Signing Block, not in `classes*.dex` or resources. Re-signing the
same APK twice with the deterministic signing command produced the same signed
APK hash.

## Reproducibility Rule For This Project

For this project, `mapping.txt` must be treated as a release input, not merely a
release output.

The reproducible statement is:

```text
source tree + canonical mapping.txt + fixed Android toolchain + deterministic signing
=> identical signed APK
```

The non-reproducible statement is:

```text
source tree alone
=> first R8 mapping.txt
=> second build with that first mapping.txt
=> identical signed APK
```

That second statement fails because the first build is a no-mapping R8 build and
the second build is an apply-mapping R8 build.

## Script Reproducibility Model

The reproducible script performs three clean APK builds of the selected
obfuscated release variant:

1. Seed build, without `-applymapping`.
   - The seed APK is saved for inspection.
   - The seed APK is not the reproducibility target.
   - Its `mapping.txt` is the input used by the next two builds.
2. Apply-mapping build 1, with
   `-Pr8ApplyMapping=<seed mapping.txt>`.
3. Apply-mapping build 2, again with the same
   `-Pr8ApplyMapping=<seed mapping.txt>`.

The script deterministically signs both apply-mapping APKs and compares their
SHA-256 hashes. The reproducibility proof is the equality of apply-mapping build
1 and apply-mapping build 2. The seed APK is expected to differ because it was
compiled in R8's no-mapping mode.

Supported variants are:

- `afatObfuscatedRelease`
- `bundleAfatObfuscatedRelease`
- `bundleAfat_SDK23ObfuscatedRelease`

## Build And Verify

```bash
Tools/build_TMessagesProj_App_obfuscated_reproducible.sh afatObfuscatedRelease
Tools/build_TMessagesProj_App_obfuscated_reproducible.sh bundleAfatObfuscatedRelease
Tools/build_TMessagesProj_App_obfuscated_reproducible.sh bundleAfat_SDK23ObfuscatedRelease
```

The script exports:

- `build_exports/TMessagesProj_App_<variant>_reproducible_<timestamp>/outputs/apk/seed-no-applymapping/app.apk`
- `build_exports/TMessagesProj_App_<variant>_reproducible_<timestamp>/outputs/mapping/seed-no-applymapping/mapping.txt`
- `build_exports/TMessagesProj_App_<variant>_reproducible_<timestamp>/outputs/apk/applymapping-1/app.apk`
- `build_exports/TMessagesProj_App_<variant>_reproducible_<timestamp>/outputs/apk/applymapping-2/app.apk`
- `build_exports/TMessagesProj_App_<variant>_reproducible_<timestamp>/outputs/REPRODUCIBILITY_RESULT.txt`

`REPRODUCIBILITY_RESULT.txt` records the task, seed mapping path, seed APK hash,
both apply-mapping APK hashes, and the final `MATCH` or `MISMATCH` result. The
script exits non-zero if the two apply-mapping APK hashes differ.

Do not pass `ANDROID_ABI` or `-Pandroid.injected.build.abi` to this script. The
ABI list belongs in `TMessagesProj_App/build.gradle`; the current
obfuscated flavors keep only the configured 64-bit ABIs.

## Why The Seed APK Is Not The Target

A normal first R8 build without `-applymapping` and an R8 build with that first
build's `mapping.txt` are not byte-identical. In this project, the difference is
in R8's DEX/profile output, including debug-position and dex layout encoding.
Limiting Gradle/R8 parallelism does not remove this difference.

The stable check is therefore:

1. Create the seed mapping with one no-mapping build.
2. Build once with that seed mapping.
3. Build again with that same seed mapping.
4. Compare the two deterministically signed apply-mapping APKs.

If those two hashes match, the obfuscated build is reproducible for the source
tree, seed mapping, Android toolchain, native archives, and signing setup used
by the script.

## Why The Script Re-Signs The APK

The app's Gradle release build signs with `TMessagesProj/config/release.keystore`
through AGP's default signing path. With this target SDK, AGP produces v1 and v2
APK signatures. The default v2 signing output can differ between signing runs,
even when the APK payload is identical.

The reproducible script therefore re-signs the final APK deterministically with:

- v1 signing enabled
- v2 signing enabled
- v3/v4 signing disabled
- `--min-sdk-version 17`
- the same release keystore, alias, and passwords from `local.properties`

This keeps a valid v1+v2 signed APK while making the signed APK bytes stable.

## R8 And Toolchain Notes

The root buildscript pins `com.android.tools:r8:8.8.34` ahead of AGP so the
build uses a known R8 version with newer reproducibility fixes than the R8
bundled with AGP 8.6.1.

For broader reproducibility, keep the build environment stable:

- use the same Android SDK build-tools version (`35.0.0`)
- use the same NDK/toolchain version
- avoid embedding host-specific build paths in native artifacts
- avoid timestamps in generated assets
- use the script's exported seed `mapping.txt` for apply-mapping verification
- keep the ABI list in Gradle rather than passing ABI parameters to the script

## Relation To F-Droid Verification

F-Droid's reproducible-build model rebuilds from source, compares against the
upstream developer APK, and publishes the developer-signed APK only when the
rebuilt artifact matches. Their verification flow uses APK signature copying:
the upstream signature is copied onto the rebuilt unsigned APK and verification
passes only if the signed bytes are compatible.

For F-Droid-style verification of this project:

1. Publish `app.apk`, `mapping.txt`, source tag, and build environment details.
2. A verifier runs
   `Tools/build_TMessagesProj_App_obfuscated_reproducible.sh <variant>`
   from the same source tree and toolchain.
3. The verifier compares the two deterministically signed apply-mapping APK
   SHA-256 hashes, or uses signature-copying tooling to compare against a
   developer-signed APK.
4. If there is a mismatch, inspect the generated diffoscope output first for
   DEX/profile, native `.so`, resource table, timestamp, path, or signing-block
   differences.

Known F-Droid-style risk areas for this repository are native code and paths:
use a stable checkout path, stable SDK/NDK versions, and avoid host-specific
metadata in native objects.

## References

- Android app shrinking, obfuscation, optimization, and retrace:
  `https://developer.android.com/build/shrink-code`
- ProGuard/R8 `-applymapping` option:
  `https://www.guardsquare.com/manual/configuration/usage`
- F-Droid reproducible builds:
  `https://f-droid.org/en/docs/Reproducible_Builds/`
- F-Droid signing keys and binary repositories:
  `https://f-droid.org/2023/09/03/reproducible-builds-signing-keys-and-binary-repos.html`
- F-Droid reproducibility status and diffoscope visibility:
  `https://f-droid.org/2025/05/21/making-reproducible-builds-visible.html`
