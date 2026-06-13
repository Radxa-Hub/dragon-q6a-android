#!/bin/bash
set -e
cd ~/q6a/glodroid
source build/envsetup.sh
lunch dragon_q6a-userdebug
echo "=== START vendorimage superimage vbmetaimage $(date) ==="
m -j8 vendorimage superimage vbmetaimage
echo "=== BUILD DONE $(date) ==="
