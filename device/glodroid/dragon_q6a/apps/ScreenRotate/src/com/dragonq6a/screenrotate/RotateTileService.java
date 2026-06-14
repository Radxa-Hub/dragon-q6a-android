// SPDX-License-Identifier: Apache-2.0
package com.dragonq6a.screenrotate;

import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;

/** Quick Settings tile: tap to rotate the screen 90 degrees clockwise. */
public class RotateTileService extends TileService {

    @Override
    public void onStartListening() {
        super.onStartListening();
        refresh();
    }

    @Override
    public void onClick() {
        super.onClick();
        RotationUtil.cycle();
        refresh();
    }

    private void refresh() {
        Tile tile = getQsTile();
        if (tile == null) {
            return;
        }
        tile.setState(Tile.STATE_ACTIVE);
        tile.setSubtitle(RotationUtil.label(getApplicationContext()));
        tile.updateTile();
    }
}
