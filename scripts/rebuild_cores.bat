@echo off
setlocal enabledelayedexpansion

REM rebuild_cores.bat - Download and package all latest RetroArch libretro cores
REM
REM Usage:
REM   rebuild_cores.bat              Build cores.7z
REM   rebuild_cores.bat --list       List all required cores
REM   rebuild_cores.bat --verify     Verify existing cores.7z

set "ROOT_DIR=%~dp0.."
set "CORES_DIR=%ROOT_DIR%\RetroArch\.retroarch\cores"
set "BUILD_DIR=%ROOT_DIR%\build\cores"
set "OUTPUT=%CORES_DIR%\cores.7z"
set "URL_BASE=https://buildbot.libretro.com/nightly/linux/aarch64/latest"

REM --- Find 7-Zip ---
set "SZ="
where 7z >nul 2>&1 && set "SZ=7z" && goto :found_7z
for %%p in (
    "A:\7-Zip\7z.exe"
    "C:\Program Files\7-Zip\7z.exe"
    "C:\Program Files (x86)\7-Zip\7z.exe"
    "%LOCALAPPDATA%\Programs\7-Zip\7z.exe"
    "%USERPROFILE%\AppData\Local\Programs\7-Zip\7z.exe"
) do (
    if exist %%p set "SZ=%%~p" & goto :found_7z
)
echo [ERROR] 7-Zip not found. Install from https://www.7-zip.org/download.html
exit /b 1
:found_7z

REM --- Find curl ---
set "CURL="
where curl.exe >nul 2>&1 && set "CURL=curl.exe" && goto :found_curl
where curl >nul 2>&1 && set "CURL=curl" && goto :found_curl
echo [ERROR] curl not found. Windows 10+ includes it, or install from https://curl.se/windows/
exit /b 1
:found_curl

REM --- Handle flags ---
if "%~1"=="--list" goto :list
if "%~1"=="--help" goto :help
if "%~1"=="-h" goto :help
if "%~1"=="--verify" goto :verify

echo.
echo ========================================
echo    RetroArch Core Rebuilder
echo ========================================
echo.

REM --- Create build dir (keep existing downloads) ---
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

REM --- Counters ---
set DOWNLOADED=0
set SKIPPED=0
set FAILED=0

echo [STEP] Downloading cores...
echo.

REM --- Download each core ---
call :download 2048
call :download 81
call :download a5200
call :download arduous
call :download atari800
call :download bluemsx
call :download cap32
call :download chailove
call :download crocods
call :download desmume2015
call :download dosbox_pure
call :download ecwolf
call :download fbalpha2012
call :download fbneo
call :download fceumm
call :download flycast
call :download fmsx
call :download freechaf
call :download freeintv
call :download fuse
call :download gambatte
call :download gearboy
call :download gearcoleco
call :download gearsystem
call :download genesis_plus_gx
call :download gme
call :download gpsp
call :download gw
call :download handy
call :download hatari
call :download lowresnx
call :download lutro
call :download mame2003_plus
call :download mednafen_lynx
call :download mednafen_ngp
call :download mednafen_pce_fast
call :download mednafen_pcfx
call :download mednafen_supafaust
call :download mednafen_supergrafx
call :download mednafen_vb
call :download mednafen_wswan
call :download melonds
call :download mesen
call :download meteor
call :download mgba
REM mupen64plus_next not available on aarch64 buildbot, using mupen64plus (GLES2)
call :download neocd
call :download nestopia
call :download np2kai
call :download numero
call :download o2em
call :download opera
call :download parallel_n64
call :download pcsx_rearmed
call :download picodrive
call :download pokemini
call :download potator
call :download ppsspp
call :download prboom
call :download prosystem
call :download puae2021
call :download px68k
call :download quasi88
call :download quicknes
call :download race
call :download reminiscence
call :download sameboy
call :download scummvm
call :download snes9x
call :download snes9x2002
call :download snes9x2005
call :download snes9x2010
call :download stella
call :download stella2014
call :download swanstation
call :download tgbdual
call :download theodore
call :download tic80
call :download tyrquake
call :download uae4arm
call :download vba_next
call :download vbam
call :download vecx
call :download vice_x128
call :download vice_x64
call :download vice_x64sc
call :download vice_xvic
call :download virtualjaguar
call :download wasm4
call :download x1
call :download xrick
call :download yabasanshiro
call :download yabause

echo.
echo [STEP] Packaging cores.7z...
cd "%BUILD_DIR%"
"%SZ%" a -t7z -mx=7 "%OUTPUT%" *.so >nul 2>&1

if exist "%OUTPUT%" (
    echo [OK] Created: %OUTPUT%
    for %%f in ("%OUTPUT%") do set "FSIZE=%%~zf"
    echo [OK] Size: %FSIZE% bytes
) else (
    echo [ERROR] Failed to create cores.7z
    exit /b 1
)

REM --- Summary ---
echo.
echo ========================================
echo    Done!
echo ========================================
echo    Downloaded: %DOWNLOADED%
echo    Skipped:    %SKIPPED%
echo    Failed:     %FAILED%
echo    Output:     %OUTPUT%
echo ========================================
echo.
echo Upload to: https://github.com/jukaLang/Packages/releases/tag/cores

REM --- Cleanup ---
cd "%ROOT_DIR%"
rmdir /s /q "%BUILD_DIR%" 2>nul

exit /b 0

REM ================================================================
REM  SUBROUTINE: download a single core
REM ================================================================
:download
set "CORE=%~1"
set "SO=%CORE%_libretro.so"
set "ZIP=%SO%.zip"
set "URL=%URL_BASE%/%ZIP%"
set "DEST=%BUILD_DIR%\%SO%"
set "ZIPDEST=%BUILD_DIR%\%ZIP%"

if exist "%DEST%" (
    echo   [SKIP] %SO% (exists)
    set /a SKIPPED+=1
    goto :eof
)

"%CURL%" -sS -L --fail -o "%ZIPDEST%" "%URL%" 2>nul
if errorlevel 1 (
    echo   [FAIL] %ZIP%
    del "%ZIPDEST%" 2>nul
    set /a FAILED+=1
    goto :eof
)

"%SZ%" x -y "%ZIPDEST%" -o"%BUILD_DIR%" >nul 2>&1
del "%ZIPDEST%" 2>nul

if exist "%DEST%" (
    echo   [OK]   %SO%
    set /a DOWNLOADED+=1
) else (
    echo   [FAIL] %SO% (extract error)
    set /a FAILED+=1
)
goto :eof

:list
echo Required cores:
echo   2048 81 a5200 arduous atari800 bluemsx cap32 chailove
echo   crocods desmume2015 dosbox_pure ecwolf fbalpha2012 fbneo
echo   fceumm flycast fmsx freechaf freeintv fuse gambatte
echo   gearboy gearcoleco gearsystem genesis_plus_gx gme gpsp
echo   gw handy hatari lowresnx lutro mame2003_plus
echo   mednafen_lynx mednafen_ngp mednafen_pce_fast mednafen_pcfx
echo   mednafen_supafaust mednafen_supergrafx mednafen_vb mednafen_wswan
echo   melonds mesen meteor mgba mupen64plus_next neocd nestopia
echo   np2kai numero o2em opera parallel_n64 pcsx_rearmed picodrive
echo   pokemini potator ppsspp prboom prosystem puae2021 px68k
echo   quasi88 quicknes race reminiscence sameboy scummvm snes9x
echo   snes9x2002 snes9x2005 snes9x2010 stella stella2014 swanstation
echo   tgbdual theodore tic80 tyrquake uae4arm vba_next vbam vecx
echo   vice_x128 vice_x64 vice_x64sc vice_xvic virtualjaguar wasm4
echo   x1 xrick yabasanshiro yabause
exit /b 0

:help
echo Usage: %~nx0 [--list^|--verify^|--help]
echo.
echo Downloads latest aarch64 RetroArch cores and packages them into cores.7z
echo.
echo Requires: 7-Zip, curl (built into Windows 10+)
exit /b 0

:verify
if not exist "%OUTPUT%" (
    echo [ERROR] cores.7z not found: %OUTPUT%
    exit /b 1
)
"%SZ%" l "%OUTPUT%" | find ".so"
echo.
"%SZ%" l "%OUTPUT%" | find /c ".so"
exit /b 0
