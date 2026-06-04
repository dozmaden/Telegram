package org.telegram.messenger;

import androidx.core.graphics.ColorUtils;

/**
 * Stateless helpers that turn an "unread since" timestamp into the dialog list's unread badge: an
 * age-based color and (for chats with no unread count) a compact, localized duration label.
 *
 * The color follows a multi-stop ramp blue -> yellow -> orange -> red -> dark red, getting both
 * warmer and darker the longer a chat stays unread. Timestamps are produced by
 * {@link UnreadMarkTimeTracker}.
 */
public class UnreadMarkBadge {

    // Age (in hours) -> badge color stops. The ramp warms blue -> yellow -> orange -> red and then
    // keeps darkening into deep reds for very old chats. Both arrays are sorted by hours and share
    // the same length; getColor() interpolates linearly between adjacent stops.
    private static final float[] STOP_HOURS = {0f, 2f, 6f, 12f, 24f, 48f, 96f};
    private static final int[] STOP_COLORS = {
            0xFF42C5F5, // 0h   bright blue
            0xFF2E8BE0, // 2h   deep blue
            0xFFF4C20D, // 6h   yellow
            0xFFF59222, // 12h  orange
            0xFFE8492F, // 24h  red
            0xFFB02418, // 48h  dark red
            0xFF7A1410, // 96h+ darkest red
    };

    private static final long MINUTE = 60L * 1000L;
    private static final long HOUR = 60L * MINUTE;
    private static final long DAY = 24L * HOUR;
    private static final long WEEK = 7L * DAY;

    private UnreadMarkBadge() {
    }

    /**
     * @return a compact, largest-unit localized label (e.g. {@code "1m"}, {@code "6h"}, {@code "5d"})
     *         describing how long the dialog has been unread.
     */
    public static String formatShort(long sinceMillis) {
        final long elapsed = Math.max(0L, System.currentTimeMillis() - sinceMillis);
        if (elapsed >= WEEK) {
            return LocaleController.formatPluralString("UnreadAgeBadgeWeeks", (int) (elapsed / WEEK));
        } else if (elapsed >= DAY) {
            return LocaleController.formatPluralString("UnreadAgeBadgeDays", (int) (elapsed / DAY));
        } else if (elapsed >= HOUR) {
            return LocaleController.formatPluralString("ShortHoursAgo", (int) (elapsed / HOUR));
        } else {
            return LocaleController.formatPluralString("ShortMinutesAgo", Math.max(1, (int) (elapsed / MINUTE)));
        }
    }

    /**
     * @return an ARGB color from the multi-stop blue -> yellow -> orange -> red -> dark red ramp,
     *         based on how long the dialog has been unread. Theme-independent so the badge always
     *         reads as the same status signal.
     */
    public static int getColor(long sinceMillis) {
        final float hours = Math.max(0L, System.currentTimeMillis() - sinceMillis) / (float) HOUR;
        final int last = STOP_HOURS.length - 1;
        if (hours <= STOP_HOURS[0]) {
            return STOP_COLORS[0];
        }
        if (hours >= STOP_HOURS[last]) {
            return STOP_COLORS[last];
        }
        for (int i = 1; i <= last; i++) {
            if (hours <= STOP_HOURS[i]) {
                final float t = (hours - STOP_HOURS[i - 1]) / (STOP_HOURS[i] - STOP_HOURS[i - 1]);
                return ColorUtils.blendARGB(STOP_COLORS[i - 1], STOP_COLORS[i], t);
            }
        }
        return STOP_COLORS[last];
    }
}
