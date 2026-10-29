@echo off
setlocal
rem Clara Combo Points - arrete la synchro entre les comptes WoW et ne la lance plus avec Windows
rem (les fichiers des comptes restent tels quels ; voir LISEZMOI.txt)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ClaraSync.ps1" -Uninstall
echo.
pause
