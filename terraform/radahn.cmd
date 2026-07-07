@echo off
setlocal

set IMAGE_NAME=radahn-dashboard
set CONTAINER_NAME=radahn-dashboard
set PORT=8000
set DIR=%~dp0
rem Remove trailing slash from DIR
set DIR=%DIR:~0,-1%

if "%1"=="" goto help
if "%1"=="start" goto start
if "%1"=="stop" goto stop
if "%1"=="logs" goto logs
if "%1"=="update" goto update
if "%1"=="help" goto help

:help
echo Usage: radahn [start^|stop^|logs^|update]
echo Commands:
echo   start   - Builds and starts the Radahn Local Dashboard container
echo   stop    - Stops the Radahn Local Dashboard container
echo   logs    - Shows the logs of the container
echo   update  - Pulls the latest version from GitHub
exit /b 1

:start
echo [Radahn] Stopping any existing container...
docker stop %CONTAINER_NAME% >nul 2>&1
docker rm %CONTAINER_NAME% >nul 2>&1

echo [Radahn] Building Docker image (this will be fast if already built)...
docker build -t %IMAGE_NAME% "%DIR%"

echo [Radahn] Starting container...
docker run -d --name %CONTAINER_NAME% -p %PORT%:8000 -v "%USERPROFILE%\.aws:/root/.aws" -v "%DIR%:/app" -w /app %IMAGE_NAME%

echo.
echo ==================================================================
echo  🚀 RADAHN DASHBOARD RUNNING AT: http://localhost:%PORT%
echo  🔒 Secured via Docker Container ^& Read-only ~\.aws
echo  🛑 To stop, run: radahn stop
echo  📜 To view logs, run: radahn logs
echo ==================================================================
exit /b 0

:stop
echo [Radahn] Stopping container...
docker stop %CONTAINER_NAME%
docker rm %CONTAINER_NAME%
echo [Radahn] Container stopped.
exit /b 0

:logs
docker logs -f %CONTAINER_NAME%
exit /b 0

:update
echo [Radahn] Updating system from GitHub...
cd /d "%DIR%\.."
git fetch origin Radahn
git reset --hard origin/Radahn
echo [Radahn] Update complete! Run 'radahn start' to apply changes.
exit /b 0
