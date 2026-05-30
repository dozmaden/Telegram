# R8 optimization and obfuscation are enabled by intentionally omitting
# -dontoptimize and -dontobfuscate. The rules below preserve only the runtime
# entry points that cannot be safely renamed or removed.

-allowaccessmodification
-keepattributes SourceFile,LineNumberTable,Signature,*Annotation*,InnerClasses,EnclosingMethod

# Android and library keep annotations.
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers,allowoptimization class * {
    @androidx.annotation.Keep *;
}
-keepclasseswithmembers,allowoptimization class * {
    @androidx.annotation.Keep <init>(...);
}

# Direct JNI exports use the Java class and native method names in the symbol.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Java members called from native through FindClass, GetMethodID, or GetFieldID.
-keep,allowoptimization,includedescriptorclasses class org.telegram.tgnet.ConnectionsManager { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.tgnet.NativeByteBuffer { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.tgnet.RequestTimeDelegate { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.tgnet.*Delegate* { *; }

-keep,allowoptimization,includedescriptorclasses class org.telegram.SQLite.** { *; }

-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.AnimatedFileDrawableStream { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.ui.Stories.recorder.FfmpegAudioWaveformLoader { *; }

-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.Instance { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.Instance$* { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.NativeInstance { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.NativeInstance$* { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.ConferenceCall { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.ConferenceCall$* { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.VoIPController { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.AudioRecordJNI { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.AudioTrackJNI { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.VoIPServerConfig { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.Resampler { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.VLog { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.JNIUtilities { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.VideoCapturerDevice { *; }
-keep,allowoptimization,includedescriptorclasses class org.telegram.messenger.voip.VoIPService$RequestedParticipant { *; }

# WebRTC generates native bindings from these annotations and also uses a broad
# native bridge surface. Keep names while still allowing method optimization.
-keep @interface org.webrtc.CalledByNative
-keep @interface org.webrtc.CalledByNativeUnchecked
-keepclassmembers,allowoptimization,includedescriptorclasses class org.webrtc.** {
    @org.webrtc.CalledByNative *;
    @org.webrtc.CalledByNativeUnchecked *;
}
-keep,allowoptimization,includedescriptorclasses class org.webrtc.** { *; }

# Android framework reflection and marshaling entry points.
-keepclassmembers,allowoptimization class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepclassmembers,allowoptimization class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}
-keepclassmembers,allowoptimization enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keep,allowoptimization class **.R$styleable { *; }

# Manifest-instantiated components. AGP keeps manifest names, and these rules
# make the intent explicit for application, service, provider, receiver, widget,
# job, and activity subclasses.
-keep,allowoptimization class * extends android.app.Application { public <init>(); }
-keep,allowoptimization class * extends android.app.Activity { public <init>(); }
-keep,allowoptimization class * extends android.app.Service { public <init>(); }
-keep,allowoptimization class * extends android.content.BroadcastReceiver { public <init>(); }
-keep,allowoptimization class * extends android.content.ContentProvider { public <init>(); }
-keep,allowoptimization class * extends android.app.job.JobService { public <init>(); }
-keep,allowoptimization class * extends android.appwidget.AppWidgetProvider { public <init>(); }

# Custom tabs Binder stubs and AndroidX MediaRouter private-field reflection.
-keep,allowoptimization class org.telegram.messenger.support.** { *; }
-keepclassmembers,allowoptimization class androidx.mediarouter.app.MediaRouteButton { *; }

# Google Play Services, ML Kit, and Huawei SDK reflection entry points.
-keep public class com.google.android.gms.* { public *; }
-keepnames @com.google.android.gms.common.annotation.KeepName class *
-keepclassmembernames class * {
    @com.google.android.gms.common.annotation.KeepName *;
}
-keep class com.google.mlkit.nl.languageid.internal.LanguageIdentificationJni { *; }
-keep class com.huawei.hianalytics.** { *; }
-keep class com.huawei.updatesdk.** { *; }
-keep class com.huawei.hms.** { *; }

# ExoPlayer extension renderers, extractors, and native decoder data classes are
# loaded by Class.forName or passed across native boundaries.
-keep,allowoptimization class com.google.android.exoplayer2.ext.** { *; }
-keep,allowoptimization,includedescriptorclasses class com.google.android.exoplayer2.extractor.FlacStreamMetadata { *; }
-keep,allowoptimization,includedescriptorclasses class com.google.android.exoplayer2.metadata.flac.PictureFrame { *; }
-keep,allowoptimization,includedescriptorclasses class com.google.android.exoplayer2.decoder.SimpleDecoderOutputBuffer { *; }
-keep,allowoptimization,includedescriptorclasses class com.google.android.exoplayer2.decoder.VideoDecoderOutputBuffer { *; }

# Constant folding for resource integers may otherwise make this entry point
# look unused to the resource shrinker.
-keepclassmembers,allowoptimization class com.google.android.exoplayer2.upstream.RawResourceDataSource {
    public static android.net.Uri buildRawResourceUri(int);
}

# Constructors and factories looked up reflectively by ExoPlayer.
-dontnote com.google.android.exoplayer2.ext.flac.FlacLibrary
-keep,allowoptimization class com.google.android.exoplayer2.ext.flac.FlacLibrary {
    public static boolean isAvailable();
}

-dontnote com.google.android.exoplayer2.ext.opus.LibopusAudioRenderer
-keep,allowoptimization class com.google.android.exoplayer2.ext.opus.LibopusAudioRenderer {
    <init>(android.os.Handler, com.google.android.exoplayer2.audio.AudioRendererEventListener, com.google.android.exoplayer2.audio.AudioProcessor[]);
}
-dontnote com.google.android.exoplayer2.ext.flac.LibflacAudioRenderer
-keep,allowoptimization class com.google.android.exoplayer2.ext.flac.LibflacAudioRenderer {
    <init>(android.os.Handler, com.google.android.exoplayer2.audio.AudioRendererEventListener, com.google.android.exoplayer2.audio.AudioProcessor[]);
}
-dontnote com.google.android.exoplayer2.ext.ffmpeg.FfmpegAudioRenderer
-keep,allowoptimization class com.google.android.exoplayer2.ext.ffmpeg.FfmpegAudioRenderer {
    <init>(android.os.Handler, com.google.android.exoplayer2.audio.AudioRendererEventListener, com.google.android.exoplayer2.audio.AudioProcessor[]);
}

-dontnote com.google.android.exoplayer2.ext.flac.FlacExtractor
-keep,allowoptimization class com.google.android.exoplayer2.ext.flac.FlacExtractor {
    <init>();
}

-dontnote com.google.android.exoplayer2.source.dash.offline.DashDownloader
-keep,allowoptimization class com.google.android.exoplayer2.source.dash.offline.DashDownloader {
    <init>(android.net.Uri, java.util.List, com.google.android.exoplayer2.offline.DownloaderConstructorHelper);
}
-dontnote com.google.android.exoplayer2.source.hls.offline.HlsDownloader
-keep,allowoptimization class com.google.android.exoplayer2.source.hls.offline.HlsDownloader {
    <init>(android.net.Uri, java.util.List, com.google.android.exoplayer2.offline.DownloaderConstructorHelper);
}
-dontnote com.google.android.exoplayer2.source.smoothstreaming.offline.SsDownloader
-keep,allowoptimization class com.google.android.exoplayer2.source.smoothstreaming.offline.SsDownloader {
    <init>(android.net.Uri, java.util.List, com.google.android.exoplayer2.offline.DownloaderConstructorHelper);
}

-dontnote com.google.android.exoplayer2.source.dash.DashMediaSource$Factory
-keepclasseswithmembers,allowoptimization class com.google.android.exoplayer2.source.dash.DashMediaSource$Factory {
    <init>(com.google.android.exoplayer2.upstream.DataSource$Factory);
}
-dontnote com.google.android.exoplayer2.source.hls.HlsMediaSource$Factory
-keepclasseswithmembers,allowoptimization class com.google.android.exoplayer2.source.hls.HlsMediaSource$Factory {
    <init>(com.google.android.exoplayer2.upstream.DataSource$Factory);
}
-dontnote com.google.android.exoplayer2.source.rtsp.RtspMediaSource$Factory
-keepclasseswithmembers,allowoptimization class com.google.android.exoplayer2.source.rtsp.RtspMediaSource$Factory {
    <init>(com.google.android.exoplayer2.upstream.DataSource$Factory);
}
-dontnote com.google.android.exoplayer2.source.smoothstreaming.SsMediaSource$Factory
-keepclasseswithmembers,allowoptimization class com.google.android.exoplayer2.source.smoothstreaming.SsMediaSource$Factory {
    <init>(com.google.android.exoplayer2.upstream.DataSource$Factory);
}

# Don't warn about checkerframework and optional annotation packages.
-dontwarn org.checkerframework.**
-dontwarn javax.annotation.**
