@echo off
REM ============================================================
REM  Auxiliary Windows toolchain, version-aligned with the Docker
REM  dev image (Elixir 1.13.4 / Erlang OTP 25.3.2.6).
REM
REM  The runtime of record is Docker (see dev_start.bat). Windows
REM  native is auxiliary only -- use it for lightweight host tasks
REM  (format / credo / a few unit tests). Do NOT use the system
REM  Elixir 1.20.4 / OTP 29 install: that pair is outside the
REM  window the committed mix.lock supports and only worked on the
REM  host via stale _build beams plus a hand edit to cowlib.
REM
REM  This script also:
REM    - points MIX_HOME at an isolated hex/rebar install built for
REM      1.13.4 (the global one is built for 1.20 and corrupts)
REM    - forces an absolute MIX_BUILD_PATH (_build_win13) so the
REM      rebar3 REBAR_CONFIG path resolves correctly on Windows
REM    - exports ERL_LIBS so path deps (vendor/kalevala) can see
REM      the root project's compiled deps (jason) while building
REM    - loads the MSVC environment (vcvars64) when available, so
REM      NIF deps (bcrypt_elixir, ...) can compile
REM
REM  Usage:
REM    win_toolchain.cmd                open an aligned cmd shell
REM    win_toolchain.cmd mix test ...   run a single command
REM ============================================================
setlocal
set "ERL_HOME=%USERPROFILE%\tools\erl-25.3.2.6"
set "ELIXIR_HOME=%USERPROFILE%\tools\elixir-1.13.4-otp25"

if not exist "%ERL_HOME%\bin\erl.exe" (
    echo [win_toolchain] ERROR: Erlang OTP 25.3.2.6 not found at "%ERL_HOME%"
    exit /b 1
)
if not exist "%ELIXIR_HOME%\bin\elixir.bat" (
    echo [win_toolchain] ERROR: Elixir 1.13.4 not found at "%ELIXIR_HOME%"
    exit /b 1
)

set "PATH=%ERL_HOME%\bin;%ELIXIR_HOME%\bin;%PATH%"

REM Keep the 1.13 toolchain isolated from the 1.20 global hex/rebar.
if exist "%USERPROFILE%\tools\mix-1.13" set "MIX_HOME=%USERPROFILE%\tools\mix-1.13"

REM Absolute paths are mandatory on Windows: a relative MIX_BUILD_PATH
REM makes Mix hand rebar3 a relative REBAR_CONFIG that rebar3 cannot
REM resolve from inside deps/<app>, silently dropping the dep config.
set "MIX_BUILD_PATH=%~dp0_build_win13"
set "ERL_LIBS=%~dp0_build_win13\lib"

REM Load MSVC so elixir_make/nmake can build C NIFs. Optional: without
REM it only the pure-BEAM deps compile.
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSINSTALL="
if exist "%VSWHERE%" for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%i"
if defined VSINSTALL if exist "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" call "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" >nul

if "%~1"=="" (
    echo [win_toolchain] Elixir 1.13.4 / OTP 25.3.2.6 - matches Docker dev image
    echo [win_toolchain] MIX_BUILD_PATH=%MIX_BUILD_PATH%
    cmd /k
) else (
    %*
)
