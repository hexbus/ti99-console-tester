@echo off
rem SPDX-License-Identifier: Apache-2.0
rem Copyright 2026 Jon Guidry (hexbus)
rem Project: https://github.com/hexbus/ti99-console-tester
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
exit /b %errorlevel%
