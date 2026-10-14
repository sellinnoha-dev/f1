@echo off
REM Lance la synchro entre ce dossier et Roblox Studio (Rojo).
REM Double-clique sur ce fichier, puis dans Studio : Plugins ^> Rojo ^> Connect.
cd /d "%~dp0"
if not exist rojo.exe (
  echo Premiere utilisation : telechargement de Rojo...
  powershell -NoProfile -Command "Invoke-WebRequest -Uri https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-windows-x86_64.zip -OutFile rojo.zip; Expand-Archive -Force rojo.zip .; Remove-Item rojo.zip"
  echo Installation du plugin Rojo dans Roblox Studio...
  rojo.exe plugin install
  echo.
  echo Plugin installe. Ferme et relance Roblox Studio si il etait ouvert.
  echo.
)
echo Synchro active. Laisse cette fenetre ouverte pendant que tu travailles.
rojo.exe serve
pause
