@echo off
setlocal
cd /d "%~dp0"
"%~dp0runtime\python.exe" "%~dp0sensors\launch.py" %*
if errorlevel 1 pause
