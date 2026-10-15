// Mac Subsystem for Android - serves the Mac's requests as files.
// Licensed under the GNU General Public License v3 or later.

package io.github.harkhowalia1.msa.bridge;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;

public final class BridgeProvider extends ContentProvider {

    @Override
    public boolean onCreate() {
        return true;
    }

    @Override
    public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        Context context = getContext();
        if (context == null) {
            throw new FileNotFoundException("no context");
        }
        List<String> path = uri.getPathSegments();
        byte[] data;
        try {
            if (path.size() == 1 && "version".equals(path.get(0))) {
                data = version(context).getBytes(StandardCharsets.UTF_8);
            } else if (path.size() == 1 && "apps.json".equals(path.get(0))) {
                data = Apps.json(context);
            } else if (path.size() == 2 && "icon".equals(path.get(0))) {
                data = Apps.icon(context, path.get(1));
            } else if (path.size() == 1 && "notifications.json".equals(path.get(0))) {
                data = NotificationRelayService.snapshot();
            } else {
                throw new FileNotFoundException(uri.toString());
            }
        } catch (FileNotFoundException e) {
            throw e;
        } catch (Exception e) {
            throw new FileNotFoundException(uri + ": " + e);
        }
        return pipe(data);
    }

    private static String version(Context context) throws PackageManager.NameNotFoundException {
        PackageInfo info = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
        return Long.toString(info.getLongVersionCode());
    }

    private static ParcelFileDescriptor pipe(final byte[] data) throws FileNotFoundException {
        final ParcelFileDescriptor[] pipe;
        try {
            pipe = ParcelFileDescriptor.createPipe();
        } catch (IOException e) {
            throw new FileNotFoundException(e.toString());
        }
        new Thread(() -> {
            try (OutputStream out = new ParcelFileDescriptor.AutoCloseOutputStream(pipe[1])) {
                out.write(data);
            } catch (IOException ignored) {
                // The reader went away.
            }
        }, "bridge-writer").start();
        return pipe[0];
    }

    @Override
    public String getType(Uri uri) {
        String last = uri.getLastPathSegment();
        return last != null && last.endsWith(".json") ? "application/json" : "application/octet-stream";
    }

    @Override
    public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
        return null;
    }

    @Override
    public Uri insert(Uri uri, ContentValues values) {
        return null;
    }

    @Override
    public int delete(Uri uri, String selection, String[] selectionArgs) {
        return 0;
    }

    @Override
    public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
        return 0;
    }
}
