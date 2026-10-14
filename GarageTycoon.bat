@echo off
title Garage Tycoon - Synchro
REM Double-clique sur ce fichier pour synchroniser le jeu avec Roblox Studio.
REM Il recupere le script de synchro depuis GitHub, puis le lance.
set "ROOT=%USERPROFILE%\GarageTycoon"
if not exist "%ROOT%" mkdir "%ROOT%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest 'https://raw.githubusercontent.com/sellinnoha-dev/f1/main/tools/sync.ps1' -OutFile '%ROOT%\sync.ps1'"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\sync.ps1"
pause
