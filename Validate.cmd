@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Validate.ps1"
set "result=%ERRORLEVEL%"
pause
exit /b %result%
