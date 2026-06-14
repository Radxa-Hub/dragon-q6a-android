// SPDX-License-Identifier: Apache-2.0
package com.dragonq6a.screenrotate;

import android.app.Activity;
import android.os.Bundle;
import android.view.Surface;
import android.view.View;
import android.widget.TextView;

/** Launcher screen with explicit orientation buttons. */
public class RotateActivity extends Activity {

    private TextView mCurrent;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_rotate);
        setTitle(R.string.heading);

        mCurrent = findViewById(R.id.current);

        bind(R.id.btn_0, Surface.ROTATION_0);
        bind(R.id.btn_90, Surface.ROTATION_90);
        bind(R.id.btn_180, Surface.ROTATION_180);
        bind(R.id.btn_270, Surface.ROTATION_270);
    }

    @Override
    protected void onResume() {
        super.onResume();
        updateCurrent();
    }

    private void bind(int viewId, final int rotation) {
        findViewById(viewId).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                RotationUtil.set(rotation);
                updateCurrent();
            }
        });
    }

    private void updateCurrent() {
        mCurrent.setText(getString(R.string.current_prefix) + RotationUtil.label(this));
    }
}
