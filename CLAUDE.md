# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This is the official **Telegram for Android** app — a very large Java/native Android codebase (the UI layer alone is hundreds of files; `tgnet/TLRPC.java` is ~75k lines of generated MTProto types). Use search tools aggressively; do not attempt to read the tree exhaustively.

## Build & Test

Builds use Gradle (`./gradlew`). Requires Android SDK 35, build-tools 35.0.0, and **NDK 27.2.12479018** (the native layer is built via CMake from `TMessagesProj/jni/CMakeLists.txt` on every build). The first build compiles a large amount of C/C++ (boringssl, ffmpeg, opus, rlottie, tde2e, voip, etc.) and is slow.

```bash
# Most common dev build — debug APK of the main app
./gradlew :TMessagesProj_App:assembleAfatDebug

# Release / standalone variants of the main app
./gradlew :TMessagesProj_App:assembleAfatRelease
./gradlew :TMessagesProj_App:assembleAfatStandalone

# Instrumented tests (require a connected device/emulator)
./gradlew :TMessagesProj_AppTests:connectedAfatDebugAndroidTest

# Run a single instrumented test class
./gradlew :TMessagesProj_AppTests:connectedAfatDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=org.telegram.tgnet.SomeGeneratedTest

# Lint (note: most lint checks are disabled / not run on release builds)
./gradlew :TMessagesProj_App:lintAfatDebug
```

There is no JVM unit-test source set. All tests are **instrumented** (`androidTest`) and are **code-generated** at build time — see below.

### Module layout

- `TMessagesProj` — the `com.android.library` that holds essentially all the code: Java/Kotlin sources (`src/main/java/org/telegram/...`), native code (`jni/`), and resources. Everything else is a thin app shell.
- `TMessagesProj_App` — the primary `com.android.application` (Play Store flavors). Depends on `:TMessagesProj`.
- `TMessagesProj_AppHuawei`, `TMessagesProj_AppHockeyApp`, `TMessagesProj_AppStandalone` — alternate distribution app shells (Huawei AppGallery, internal beta/AppCenter, direct-download/web).
- `TMessagesProj_AppTests` — instrumented test app shell.
- `buildSrc` — Gradle plugin (`test-generator`) + Kotlin TL-schema tooling.

### Build flavors & types (important when picking a task name)

`TMessagesProj_App` has a single `flavorDimensions "minApi"` with many flavors: `afat`/`afatObfuscated`, `bundleAfat*`, and `*_SDK23*` variants. `Obfuscated` flavors use `proguard-rules-obfuscated.pro` and enable real R8 optimization + resource shrinking; the non-obfuscated release flavors use `proguard-rules.pro` which globally sets `-dontoptimize`/`-dontobfuscate`. A `variantFilter` ignores any non-`afat`, non-`release` combination, so most useful task names are `assemble{Afat,...}{Debug,Release,Standalone}`.

`TMessagesProj` (the library) defines build *types* `debug`, `HA_private`, `HA_public`, `HA_hardcore`, `standalone`, `release` whose `buildConfigField`s (`DEBUG_VERSION`, `DEBUG_PRIVATE_VERSION`, `VERSION_NUM`, etc.) gate behavior throughout the app — check `BuildVars.java` / `BuildConfig` before assuming a code path is reachable in a given build.

### Reproducible builds

`Tools/` contains the reproducible-build pipeline (`build_TMessagesProj_App_obfuscated_reproducible.sh`, `_build_variant_common.sh`, etc.) and `Tools/REPRODUCIBLE_BUILDS.md`. The obfuscated reproducible flow builds once to seed `mapping.txt`, then rebuilds twice with `-applymapping` and compares SHA-256. Pass an R8 mapping to the app build via the `-PR8ApplyMapping=<path>` Gradle property. **Do not** add ABI properties to these scripts — ABIs are fixed in Gradle (currently `arm64-v8a`, `x86_64` only; 32-bit ABIs are commented out in the build files).

`gradle.properties` carries `APP_VERSION_CODE` / `APP_VERSION_NAME` and **dummy** signing secrets + a dummy `release.keystore` / `google-services.json` to keep the public repo buildable and reproducible (per upstream policy). Real publishing requires replacing the keystore, `google-services.json`, and the values in `BuildVars.java`.

## Architecture

### Per-account singletons (`BaseController` / `AccountInstance`)

The app supports up to `UserConfig.MAX_ACCOUNT_COUNT` (= 4) simultaneously logged-in accounts. Almost every piece of "backend" logic is a **per-account singleton** indexed by an `int currentAccount`. The big ones live in `org.telegram.messenger`:

- `MessagesController`, `MessagesStorage` (SQLite cache), `MediaDataController`, `ContactsController`, `NotificationsController`, `DownloadController`, `FileLoader`, `SendMessagesHelper`, `UserConfig`, `ConnectionsManager`, plus dozens more `*Controller` classes.

`AccountInstance.getInstance(num)` is the registry of these singletons for one account. Classes that need them extend `BaseController` and call `getMessagesController()`, `getMessagesStorage()`, etc. (all routed through the account's `AccountInstance`). When writing backend code, thread `currentAccount` through and resolve services this way rather than reaching for a global.

Process-wide (not per-account) state lives in singletons like `ApplicationLoader` (app entry/init), `SharedConfig` (device-global settings), `AndroidUtilities`, `LocaleController`, and `ImageLoader`.

### NotificationCenter (event bus)

`NotificationCenter` is the app-wide observer/event bus and is also per-account (plus a `getGlobalInstance()`). Components `addObserver(this, NotificationCenter.someEvent)` and post with `postNotificationName(...)`. This is the primary decoupling mechanism between controllers and UI — expect side effects to propagate through it rather than direct calls. Always remove observers to avoid leaks.

### Network / MTProto (`tgnet`)

`org.telegram.tgnet` is the MTProto client. `ConnectionsManager` is a thin Java wrapper over native code (`native_*` JNI methods; the real implementation is in `jni/tgnet/`). The TL (Type Language) wire schema is represented by `TLRPC.java` and the `tgnet/tl/` package — huge generated files of `TLObject` subclasses with `serializeToStream` / `readParams`. Requests are `TLObject`/`TLMethod` instances sent via `ConnectionsManager.sendRequest(...)` with a `RequestDelegate` callback.

**TL schema tests are generated**: the `test-generator` plugin (`buildSrc`, wired in `TestGeneratorPlugin.kt`) runs `GenerateSchemeTask` before `preBuild` of `TMessagesProj_AppTests`, parsing the `tgnet` sources + `tlscheme/` resources to emit serialization round-trip tests into `src/androidTest/kotlin`. Regenerate by rebuilding the test module; don't hand-edit generated tests.

### UI (`org.telegram.ui`)

The UI does **not** use standard Android `Activity`/`Fragment`. It is built on a custom in-house framework in `org.telegram.ui.ActionBar` (`BaseFragment`, `ActionBar`, `Theme`, `AlertDialog`, bottom sheets). Screens are classes named `*Activity` (e.g. `ChatActivity`, `DialogsActivity`) that extend `BaseFragment` and are hosted inside a single Android `Activity` (`LaunchActivity`) via a fragment stack. Most views are hand-drawn custom `View`s (`ui/Cells`, `ui/Components`) rather than XML layouts; theming goes through `Theme` and theme-description descriptors, not Android styles. RecyclerView is replaced by a bundled fork (`androidx.recyclerview` is excluded in every module's `build.gradle`).

### Native (`TMessagesProj/jni`)

C/C++ for crypto (`boringssl`, `tde2e`), media (`ffmpeg`, `opus`, `mozjpeg`, `webm`, `exoplayer`), animation (`rlottie`/`lottie`), voice/video calls (`voip`/libtgvoip + WebRTC), the SQLite wrapper, and the tgnet MTProto core. Reached from Java through JNI wrappers like `ConnectionsManager`, `NativeLoader`, `Utilities`, `TgNetWrapper`.

## Conventions

- Match the surrounding file's style. The codebase predates modern Android idioms: Java-first, manual threading (`DispatchQueue`, `AndroidUtilities.runOnUIThread`), few external DI/reactive libraries, custom views over XML.
- Localization is managed externally at translations.telegram.org. `lint` has `MissingTranslation`/`ExtraTranslation` disabled — do not add string translations by hand.
- New backend services follow the per-account `BaseController` pattern; new screens follow the `BaseFragment` pattern.
