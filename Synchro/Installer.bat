@echo off
setlocal
rem Clara Combo Points - installe la synchro entre les comptes WoW (voir LISEZMOI.txt)
rem Le dossier de WoW Forever (celui qui contient WTF) ; a changer ici si besoin :
set "WOW=F:\Jeux\World of Warcraft\_forever_"
if exist "%WOW%\WTF\Account" goto found
echo Dossier introuvable : %WOW%\WTF\Account
set /p "WOW=Chemin du dossier _forever_ de WoW (celui qui contient WTF) : "
:found
set "WOW=%WOW:"=%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ClaraSync.ps1" -Wow "%WOW%" -Install
echo.
pause
