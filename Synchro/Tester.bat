@echo off
setlocal
rem Clara Combo Points - montre ce que la synchro ferait, sans rien ecrire (voir LISEZMOI.txt)
set "WOW=F:\Jeux\World of Warcraft\_forever_"
if exist "%WOW%\WTF\Account" goto found
echo Dossier introuvable : %WOW%\WTF\Account
set /p "WOW=Chemin du dossier _forever_ de WoW (celui qui contient WTF) : "
:found
set "WOW=%WOW:"=%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ClaraSync.ps1" -Wow "%WOW%" -Once -Test
echo.
pause
