// Mac Subsystem for Android - keeps Android's active notifications for the Mac.
//
// The Mac grants this listener with
//   cmd notification allow_listener io.github.harkhowalia1.msa.bridge/.NotificationRelayService
// and reads notifications.json every few seconds.
//
// Licensed under the GNU General Public License v3 or later.

package io.github.harkhowalia1.msa.bridge;

import android.app.Notification;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.nio.charset.StandardCharsets;

public final class NotificationRelayService extends NotificationListenerService {
    private static volatile NotificationRelayService connected;

    @Override
    public void onListenerConnected() {
        connected = this;
    }

    @Override
    public void onListenerDisconnected() {
        if (connected == this) {
            connected = null;
        }
    }

    static byte[] snapshot() throws JSONException {
        JSONArray list = new JSONArray();
        NotificationRelayService service = connected;
        if (service != null) {
            StatusBarNotification[] active;
            try {
                active = service.getActiveNotifications();
            } catch (RuntimeException e) {
                active = null;
            }
            if (active != null) {
                for (StatusBarNotification sbn : active) {
                    Notification notification = sbn.getNotification();
                    if ((notification.flags & Notification.FLAG_GROUP_SUMMARY) != 0) {
                        continue;
                    }
                    Bundle extras = notification.extras;
                    CharSequence title = extras.getCharSequence(Notification.EXTRA_TITLE);
                    CharSequence text = extras.getCharSequence(Notification.EXTRA_BIG_TEXT);
                    if (text == null) {
                        text = extras.getCharSequence(Notification.EXTRA_TEXT);
                    }
                    JSONObject item = new JSONObject();
                    item.put("key", sbn.getKey());
                    item.put("package", sbn.getPackageName());
                    item.put("title", title != null ? title.toString() : "");
                    item.put("text", text != null ? text.toString() : "");
                    item.put("posted", sbn.getPostTime());
                    item.put("ongoing", sbn.isOngoing());
                    list.put(item);
                }
            }
        }
        return list.toString().getBytes(StandardCharsets.UTF_8);
    }
}
