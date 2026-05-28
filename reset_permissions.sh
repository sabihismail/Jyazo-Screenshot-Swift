#!/bin/bash
# Reset ScreenShot app permissions after build
BUNDLE_ID="arkaprime.Jyazo"

echo "[BUILD] Resetting TCC permissions for $BUNDLE_ID..."

# Reset Screen Recording
if tccutil reset ScreenCapture "$BUNDLE_ID" 2>/dev/null; then
    echo "✓ Reset Screen Recording permission"
else
    echo "✗ Failed to reset Screen Recording"
fi

# Reset Accessibility
if tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null; then
    echo "✓ Reset Accessibility permission"
else
    echo "✗ Failed to reset Accessibility"
fi

echo "[BUILD] Permission reset complete - app will request permissions on next launch"
