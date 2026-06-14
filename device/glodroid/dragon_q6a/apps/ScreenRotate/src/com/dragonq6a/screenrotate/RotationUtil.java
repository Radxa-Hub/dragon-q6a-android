// SPDX-License-Identifier: Apache-2.0
package com.dragonq6a.screenrotate;

import android.content.Context;
import android.os.RemoteException;
import android.util.Log;
import android.view.IWindowManager;
import android.view.Surface;
import android.view.WindowManagerGlobal;

/**
 * Thin wrapper over IWindowManager rotation control. freezeRotation() locks the
 * display to a fixed rotation (the same call the system rotation lock uses); it
 * needs the signature permission SET_ORIENTATION, granted via the platform cert.
 */
final class RotationUtil {
    private static final String TAG = "ScreenRotate";

    private RotationUtil() {}

    private static IWindowManager wm() {
        return WindowManagerGlobal.getWindowManagerService();
    }

    /** Current display rotation as a Surface.ROTATION_* constant. */
    static int current() {
        try {
            return wm().getDefaultDisplayRotation();
        } catch (RemoteException e) {
            Log.e(TAG, "getDefaultDisplayRotation failed", e);
            return Surface.ROTATION_0;
        }
    }

    /** Lock the display to the given Surface.ROTATION_* value. */
    static void set(int rotation) {
        try {
            wm().freezeRotation(rotation);
        } catch (RemoteException e) {
            Log.e(TAG, "freezeRotation failed", e);
        }
    }

    /** Advance 90 degrees clockwise. */
    static void cycle() {
        set((current() + 1) % 4);
    }

    /** Human-readable label for the current rotation. */
    static String label(Context c) {
        switch (current()) {
            case Surface.ROTATION_90:
                return c.getString(R.string.rot_90);
            case Surface.ROTATION_180:
                return c.getString(R.string.rot_180);
            case Surface.ROTATION_270:
                return c.getString(R.string.rot_270);
            case Surface.ROTATION_0:
            default:
                return c.getString(R.string.rot_0);
        }
    }
}
