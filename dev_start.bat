@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  ExVenture / Kalevala MUD - one-click dev bootstrap (Windows)
REM  Usage:
REM    dev_start.bat          full flow: db -> deps -> ecto -> (force recompile) -> phx.server
REM                              会自动停掉已在运行的 app 容器再启动，因此也能用于「重启」
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

echo [dev_start] [3/3] (Re)starting Phoenix server with forced recompile...
echo             (code_reloader off + Docker bind-mount mtime quirks can make
echo             incremental compile skip recompile, so we force recompile on
echo             every container start to ensure new code loads.)
echo             Web client : http://localhost:4000
echo             Telnet MUD : telnet localhost 4646
REM 先停掉已在运行的 app 容器，否则 `up app` 会判定「已在运行」而变成空操作，
REM 导致新编译的 BEAM 不会被加载（dev 关闭了 code_reloader）。
%COMPOSE% stop app 2>nul
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
