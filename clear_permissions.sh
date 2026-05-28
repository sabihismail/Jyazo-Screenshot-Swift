#!/bin/bash
echo "[TCC] Clearing permissions for arkaprime.Jyazo..."
sudo tccutil reset Accessibility arkaprime.Jyazo && echo "✓ Accessibility cleared"
sudo tccutil reset ScreenCapture arkaprime.Jyazo && echo "✓ ScreenCapture cleared"
echo "[TCC] Done - app will prompt for permissions on next launch"
