#!/bin/bash
echo "[TCC] Clearing permissions for arkaprime.Jyazo..."
sudo tccutil reset Accessibility arkaprime.Jyazo && echo "✓ Accessibility cleared"
sudo tccutil reset ScreenCapture arkaprime.Jyazo && echo "✓ ScreenCapture cleared"
sudo tccutil reset SystemAudioRecording arkaprime.Jyazo && echo "✓ SystemAudioRecording cleared"
echo "[TCC] Done - app will prompt for permissions on next launch"
