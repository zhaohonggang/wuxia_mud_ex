@echo off
setlocal enabledelayedexpansion

set COMPOSE_FILE=docker-compose.dev.yml
set VOLUME_NAME=wuxia_mud_dev_app_build

echo ============================================================
echo  Wuxia MUD Docker build cache cleaner
echo ============================================================
echo.

docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [Error] docker command not found. Please ensure Docker Desktop is running.
    pause
    exit /b 1
)

echo [1/3] Stopping docker compose containers...
docker compose -f %COMPOSE_FILE% down

echo [2/3] Removing build cache volume "%VOLUME_NAME%"...
docker volume rm %VOLUME_NAME% >nul 2>&1
if %errorlevel% equ 0 (
    echo   Removed "%VOLUME_NAME%".
) else (
    echo   Volume "%VOLUME_NAME%" not found or already removed.
)

echo [3/3] Cleaning Docker builder cache...
docker builder prune -f >nul 2>&1

echo.
echo ============================================================
echo  Done.
echo  Restart the game container:
echo    docker compose -f %COMPOSE_FILE% up --build
echo.
echo  Then test in-game:
echo    goto chengdu:kedian
echo    hints
echo    pay xiaoer 5000 coin
echo ============================================================
pause
