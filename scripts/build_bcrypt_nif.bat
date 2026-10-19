@echo off
rem ===========================================================================
rem  build_bcrypt_nif.bat - build bcrypt_elixir's NIF (bcrypt_nif.dll) by hand
rem
rem  WHY THIS EXISTS
rem  ---------------------------------------------------------------------------
rem  "mix deps.compile bcrypt_elixir" fails on this machine (Chinese Windows +
rem  Elixir 1.20.4) for two environment reasons, neither of them a code bug:
rem
rem  1) elixir_make 0.6.2 shells out to "nmake /F Makefile.win" on Windows, but
rem     nmake is not on PATH, and vcvars64.bat calls reg.exe, which is blocked by
rem     the local security policy - so the Windows SDK INCLUDE/LIB never get set
rem     and cl fails with: bcrypt_nif.c(52): fatal error C1083: cannot open
rem     include file: 'stdio.h'.
rem     Fix: skip vcvars and set PATH/INCLUDE/LIB by hand (see vars below).
rem
rem  2) Even with nmake working, cl/nmake print their banner in CP936 Chinese
rem     bytes and Elixir 1.20's System.cmd decodes stdout as UTF-8 and crashes:
rem       ** (ArgumentError) argument error
rem          (elixir) System.do_port_byte/3
rem          (elixir_make) lib/mix/tasks/compile.make.ex:223
rem     VSLANG=1033 and chcp 65001 do not help.
rem     Fix: bypass elixir_make entirely and run nmake from cmd.
rem
rem  The dll lands in deps\bcrypt_elixir\priv\ and is then made available to
rem  each _build\<env>\lib\bcrypt_elixir\priv (that is what :code.priv_dir/1
rem  points at). Note that _build\test\...\priv may be a *junction* to
rem  deps\bcrypt_elixir\priv, so never "del" the dll there - it would delete the
rem  real file. This script only ever copies and then checks for presence.
rem
rem  deps\ and _build\ are gitignored, so the dll is not committed: re-run this
rem  script after a fresh "mix deps.get" or after "mix deps.clean".
rem
rem  NOTE: the MSVC / Windows SDK version numbers below are hardcoded. If the
rem  toolchain is upgraded, update them. Discover the current ones with:
rem    "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" ^
rem      -all -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
rem      -property installationPath
rem  and look under C:\Program Files (x86)\Windows Kits\10\Include\
rem ===========================================================================
setlocal
chcp 65001 >nul 2>&1

set "MSVC=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207"
set "SDK=C:\Program Files (x86)\Windows Kits\10"
set "SDK_VSN=10.0.26100.0"
set "ERTS_INCLUDE=C:\Program Files\Erlang OTP\erts-17.1.1\include"

set "PATH=%MSVC%\bin\Hostx64\x64;%PATH%"
set "INCLUDE=%MSVC%\include;%SDK%\Include\%SDK_VSN%\ucrt;%SDK%\Include\%SDK_VSN%\shared;%SDK%\Include\%SDK_VSN%\um"
set "LIB=%MSVC%\lib\x64;%SDK%\Lib\%SDK_VSN%\ucrt\x64;%SDK%\Lib\%SDK_VSN%\um\x64"
set "ERTS_INCLUDE_PATH=%ERTS_INCLUDE%"

set "ROOT=%~dp0.."
set "DLL=%ROOT%\deps\bcrypt_elixir\priv\bcrypt_nif.dll"

pushd "%ROOT%\deps\bcrypt_elixir" 2>nul || goto :nodeps

echo === nmake: bcrypt_nif.dll ===
nmake /F Makefile.win priv\bcrypt_nif.dll
if errorlevel 1 goto :buildfail
popd

if not exist "%DLL%" goto :buildfail
echo built: %DLL%

for %%E in (dev test) do call :publish %%E

echo.
if defined MISSING (
  echo FAILED - some _build env still has no bcrypt_nif.dll.
  exit /b 1
)
echo OK - verify with:
echo   MIX_ENV=test mix run --no-start -e "IO.inspect(Bcrypt.verify_pass(\"x\", Bcrypt.hash_pwd_salt(\"x\")))"
exit /b 0

:publish
set "ENVNAME=%~1"
set "DEST=%ROOT%\_build\%ENVNAME%\lib\bcrypt_elixir\priv"
if not exist "%ROOT%\_build\%ENVNAME%\lib\bcrypt_elixir" exit /b 0
if not exist "%DEST%" mkdir "%DEST%"
rem copy may legitimately fail when DEST is a junction/hardlink onto deps, so
rem success is decided by presence afterwards, not by errorlevel.
copy /Y "%DLL%" "%DEST%\" >nul 2>&1
if exist "%DEST%\bcrypt_nif.dll" (
  echo published: _build\%ENVNAME%\lib\bcrypt_elixir\priv
) else (
  echo WARNING: %DEST%\bcrypt_nif.dll missing - dll locked by a running BEAM?
  echo          Stop it ^(mix test / iex / phx.server^) and re-run this script.
  set "MISSING=1"
)
exit /b 0

:nodeps
echo ERROR: deps\bcrypt_elixir not found. Run "mix deps.get" first.
exit /b 1

:buildfail
echo ERROR: bcrypt NIF build failed.
popd
exit /b 1
