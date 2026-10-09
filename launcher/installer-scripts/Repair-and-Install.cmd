@echo off
rem ASCII-only on purpose: cmd.exe misreads a UTF-8 BOM, and this file must
rem survive being double-clicked on a machine we cannot touch. The Russian text
rem lives in Repair-and-Install.ps1, which is invoked with a BOM.
setlocal
title Valkyrie Launcher - repair and install
chcp 65001 >nul 2>&1

set "PS_SCRIPT=%~dp0Repair-and-Install.ps1"
if not exist "%PS_SCRIPT%" (
    echo Repair-and-Install.ps1 is missing next to this file.
    pause
    exit /b 2
)

set "SHELL_EXE="
where powershell.exe >nul 2>&1 && set "SHELL_EXE=powershell.exe"
if not defined SHELL_EXE where pwsh.exe >nul 2>&1 && set "SHELL_EXE=pwsh.exe"
if not defined SHELL_EXE (
    echo PowerShell was not found on this system.
    pause
    exit /b 3
)

"%SHELL_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
set "EXITCODE=%ERRORLEVEL%"

echo.
if "%EXITCODE%"=="0" (
    echo Done. Valkyrie Launcher is installed.
) else (
    echo Finished with exit code %EXITCODE%. See the messages above.
)
echo.
pause
exit /b %EXITCODE%
