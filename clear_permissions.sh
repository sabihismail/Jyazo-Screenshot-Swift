#!/bin/bash
echo "[TCC] Clearing permissions for arkaprime.ScreenShot..."
sudo tccutil reset Accessibility arkaprime.ScreenShot && echo "✓ Accessibility cleared"
sudo tccutil reset ScreenCapture arkaprime.ScreenShot && echo "✓ ScreenCapture cleared"
sudo tccutil reset SystemAudioRecording arkaprime.ScreenShot && echo "✓ SystemAudioRecording cleared"
echo "[TCC] Done - app will prompt for permissions on next launch"
