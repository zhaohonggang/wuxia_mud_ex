@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  ExVenture / Kalevala MUD - one-click dev bootstrap (Windows)
REM  Usage:
REM    dev_start.bat          full flow: db -> deps -> ecto -> phx.server
REM    dev_start.bat reset    drop + recreate + reseed database, then serve
REM    dev_start.bat stop     stop all containers (data volumes kept)
REM    dev_start.bat clean    stop and DELETE all data volumes (fresh start)
REM ============================================================

set "COMPOSE=docker compose -f docker-compose.dev.yml"

echo [dev_start] Checking Docker engine...
docker info >nul 2>&1
if errorlevel 1 (
    echo [dev_start] Docker engine not running - starting Docker Desktop...
    if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" (
        start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
    ) else (
        echo [dev_start] ERROR: Docker Desktop not found at default path.
        exit /b 1
    )
    set /a tries=0
    :wait_engine
    timeout /t 3 /nobreak >nul
    docker info >nul 2>&1
    if errorlevel 1 (
        set /a tries+=1
        if !tries! geq 40 (
            echo [dev_start] ERROR: Docker engine did not come up in time.
            exit /b 1
        )
        goto :wait_engine
    )
)
echo [dev_start] Docker engine is up.

if "%~1"=="stop"  goto :stop
if "%~1"=="clean" goto :clean
if "%~1"=="reset" goto :reset

echo [dev_start] [1/3] Starting PostgreSQL (db)...
%COMPOSE% up -d db
if errorlevel 1 goto :fail

echo [dev_start] [2/3] Bootstrapping project (mix deps.get + yarn install + ecto.setup)...
%COMPOSE% run --rm setup
if errorlevel 1 goto :fail

echo [dev_start] [3/3] Launching Phoenix server (foreground, Ctrl+C to stop)...
echo             Web client : http://localhost:4000
echo             Telnet MUD : telnet localhost 4646
%COMPOSE% up app
goto :eof

:reset
echo [dev_start] Resetting database (ecto.reset = drop + create + migrate + seed)...
%COMPOSE% up -d db
%COMPOSE% run --rm app sh -c "mix ecto.reset && rm -f /root/.mix/.exventure_seeded && touch /root/.mix/.exventure_seeded"
if errorlevel 1 goto :fail
echo [dev_start] Reset done. Run "dev_start.bat" to boot the server.
goto :eof

:stop
%COMPOSE% down
goto :eof

:clean
echo [dev_start] WARNING: deleting ALL dev data (database, deps caches, node_modules).
choice /C YN /M "Type Y to confirm"
if errorlevel 2 goto :eof
%COMPOSE% down -v
goto :eof

:fail
echo.
echo [dev_start] FAILED - see output above.
exit /b 1
