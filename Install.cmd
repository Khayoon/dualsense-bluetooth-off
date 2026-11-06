@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%~dp0Install-ControllerOff.ps1"
if errorlevel 1 (
    echo.
    echo Setup could not finish. See the message above.
    pause
    exit /b 1
)
echo.
pause
