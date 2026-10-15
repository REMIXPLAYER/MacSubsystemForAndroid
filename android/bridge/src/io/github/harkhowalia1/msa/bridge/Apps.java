// Mac Android Subsystem - the list of launchable apps and their icons.
// Licensed under the GNU General Public License v3 or later.

package io.github.harkhowalia1.msa.bridge;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.AdaptiveIconDrawable;
import android.graphics.drawable.Drawable;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

final class Apps {
    private static final int ICON_SIZE = 512;

    private Apps() {
    }

    static byte[] json(Context context) throws JSONException {
        PackageManager pm = context.getPackageManager();
        Intent main = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> activities = pm.queryIntentActivities(main, 0);
        JSONArray apps = new JSONArray();
        Set<String> seen = new HashSet<>();
        for (ResolveInfo info : activities) {
            ActivityInfo activity = info.activityInfo;
            if (activity == null || !seen.add(activity.packageName)) {
                continue;
            }
            JSONObject app = new JSONObject();
            app.put("package", activity.packageName);
            app.put("activity", new ComponentName(activity.packageName, activity.name).flattenToShortString());
            app.put("label", String.valueOf(info.loadLabel(pm)));
            ApplicationInfo application = activity.applicationInfo;
            boolean system = application != null
                    && (application.flags & (ApplicationInfo.FLAG_SYSTEM | ApplicationInfo.FLAG_UPDATED_SYSTEM_APP)) != 0;
            app.put("system", system);
            // Games declare android:appCategory="game" (or the older isGame flag).
            boolean game = application != null
                    && (application.category == ApplicationInfo.CATEGORY_GAME
                        || (application.flags & ApplicationInfo.FLAG_IS_GAME) != 0);
            app.put("game", game);
            app.put("adaptive", info.loadIcon(pm) instanceof AdaptiveIconDrawable);
            try {
                PackageInfo packageInfo = pm.getPackageInfo(activity.packageName, 0);
                app.put("versionName", packageInfo.versionName != null ? packageInfo.versionName : "");
                app.put("updated", packageInfo.lastUpdateTime);
            } catch (PackageManager.NameNotFoundException e) {
                app.put("versionName", "");
                app.put("updated", 0);
            }
            apps.put(app);
        }
        return apps.toString().getBytes(StandardCharsets.UTF_8);
    }

    /** The launcher icon at 512x512. Adaptive icons are drawn edge to edge (no mask), so the Mac can shape them. */
    static byte[] icon(Context context, String packageName) throws PackageManager.NameNotFoundException {
        PackageManager pm = context.getPackageManager();
        Intent launch = pm.getLaunchIntentForPackage(packageName);
        Drawable drawable = launch != null ? pm.getActivityIcon(launch) : pm.getApplicationIcon(packageName);

        Bitmap bitmap = Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        if (drawable instanceof AdaptiveIconDrawable) {
            AdaptiveIconDrawable adaptive = (AdaptiveIconDrawable) drawable;
            drawLayer(adaptive.getBackground(), canvas);
            drawLayer(adaptive.getForeground(), canvas);
        } else {
            drawable.setBounds(0, 0, ICON_SIZE, ICON_SIZE);
            drawable.draw(canvas);
        }
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
        bitmap.recycle();
        return out.toByteArray();
    }

    private static void drawLayer(Drawable layer, Canvas canvas) {
        if (layer == null) {
            return;
        }
        layer.setBounds(0, 0, ICON_SIZE, ICON_SIZE);
        layer.draw(canvas);
    }
}
