package org.telegram.messenger;

import android.content.Context;
import android.content.SharedPreferences;

import org.telegram.messenger.support.LongSparseLongArray;

import java.util.Map;

/**
 * Tracks since when each dialog has been unread, so the dialog list can age its unread badge
 * (see {@link UnreadMarkBadge}).
 *
 * A dialog is considered unread when it has unread messages ({@code unread_count > 0}) or is
 * manually flagged ({@code unread_mark}). Telegram stores neither a "first unread" timestamp nor a
 * "marked at" timestamp, so this per-account tracker records one locally: on the first render where
 * a dialog is seen unread it stamps the supplied time (the dialog's first unread message time, or
 * the current time when none is available), and clears it once the dialog is rendered as read.
 *
 * State is persisted in a dedicated per-account {@link SharedPreferences} file and is fed entirely
 * from {@code DialogCell} as it binds, keeping all of the new logic isolated here without touching
 * {@code MessagesController}/{@code MessagesStorage}.
 */
public class UnreadMarkTimeTracker {

    private static final String PREFS_PREFIX = "unreadmarktime";
    private static final String KEY_PREFIX = "d";

    private static final UnreadMarkTimeTracker[] instances = new UnreadMarkTimeTracker[UserConfig.MAX_ACCOUNT_COUNT];

    public static UnreadMarkTimeTracker getInstance(int account) {
        UnreadMarkTimeTracker local = instances[account];
        if (local == null) {
            synchronized (UnreadMarkTimeTracker.class) {
                local = instances[account];
                if (local == null) {
                    local = instances[account] = new UnreadMarkTimeTracker(account);
                }
            }
        }
        return local;
    }

    private final SharedPreferences preferences;
    private final LongSparseLongArray markedAt = new LongSparseLongArray();

    private UnreadMarkTimeTracker(int account) {
        preferences = ApplicationLoader.applicationContext.getSharedPreferences(PREFS_PREFIX + account, Context.MODE_PRIVATE);
        for (Map.Entry<String, ?> entry : preferences.getAll().entrySet()) {
            final String key = entry.getKey();
            final Object value = entry.getValue();
            if (key != null && key.startsWith(KEY_PREFIX) && value instanceof Long) {
                try {
                    markedAt.put(Long.parseLong(key.substring(KEY_PREFIX.length())), (Long) value);
                } catch (NumberFormatException ignore) {
                }
            }
        }
    }

    /**
     * Records or clears the "unread since" timestamp for a dialog.
     *
     * @param unread            the dialog's current unread state, as resolved by the caller.
     * @param unreadSinceMillis the time the dialog became unread (e.g. the first unread message's
     *                          date) in millis, or {@code 0} to fall back to the current time.
     *                          Only used on the first transition to {@code unread}; once stored the
     *                          value is kept until the dialog is read. A {@code false} state clears
     *                          any stored time.
     */
    public void track(long dialogId, boolean unread, long unreadSinceMillis) {
        if (unread) {
            if (markedAt.indexOfKey(dialogId) < 0) {
                final long now = System.currentTimeMillis();
                final long since = (unreadSinceMillis > 0 && unreadSinceMillis <= now) ? unreadSinceMillis : now;
                markedAt.put(dialogId, since);
                preferences.edit().putLong(KEY_PREFIX + dialogId, since).apply();
            }
        } else {
            if (markedAt.indexOfKey(dialogId) >= 0) {
                markedAt.delete(dialogId);
                preferences.edit().remove(KEY_PREFIX + dialogId).apply();
            }
        }
    }

    /**
     * @return the millis timestamp since when the dialog has been unread, or {@code 0} if there is
     *         no stored timestamp.
     */
    public long getUnreadSinceTime(long dialogId) {
        return markedAt.get(dialogId, 0L);
    }
}
