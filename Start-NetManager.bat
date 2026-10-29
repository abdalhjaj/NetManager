@echo off
title NetManager - Local Server
cd /d "D:\Projects\NetManager-Recovered\netmanager_app"

echo =====================================
echo       Starting NetManager
echo =====================================
echo.

flutter run -d chrome

echo.
echo NetManager has stopped.
pause
