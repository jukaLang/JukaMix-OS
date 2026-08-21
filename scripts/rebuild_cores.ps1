# rebuild_cores.ps1 - Download and package all latest RetroArch libretro cores
#
# Usage:
#   .\scripts\rebuild_cores.ps1              Build cores.7z
#   .\scripts\rebuild_cores.ps1 -List        List all required cores
#   .\scripts\rebuild_cores.ps1 -Verify      Verify existing cores.7z

param(
    [switch]$List,
    [switch]$Verify,
    [switch]$Help
)

$ErrorActionPreference = "Continue"

# Paths
$RootDir = Split-Path -Parent $PSScriptRoot
$CoresDir = Join-Path $RootDir "RetroArch\.retroarch\cores"
$BuildDir = Join-Path $RootDir "build\cores"
$Output = Join-Path $CoresDir "cores.7z"
$BaseUrl = "https://buildbot.libretro.com/nightly/linux/aarch64/latest"

# All required cores
$RequiredCores = @(
    "2048","81","a5200","arduous","atari800","bluemsx","cap32","chailove",
    "crocods","desmume2015","dosbox_pure","ecwolf","fbalpha2012","fbneo",
    "fceumm","flycast","fmsx","freechaf","freeintv","fuse","gambatte",
    "gearboy","gearcoleco","gearsystem","genesis_plus_gx","gme","gpsp",
    "gw","handy","hatari","lowresnx","lutro","mame2003_plus",
    "mednafen_lynx","mednafen_ngp","mednafen_pce_fast","mednafen_pcfx",
    "mednafen_supafaust","mednafen_supergrafx","mednafen_vb","mednafen_wswan",
    "melonds","mesen","meteor","mgba","mupen64plus","neocd","nestopia",
    "np2kai","numero","o2em","opera","parallel_n64","pcsx_rearmed","picodrive",
    "pokemini","potator","ppsspp","prboom","prosystem","puae2021","px68k",
    "quasi88","quicknes","race","reminiscence","sameboy","scummvm","snes9x",
    "snes9x2002","snes9x2005","snes9x2010","stella","stella2014","swanstation",
    "tgbdual","theodore","tic80","tyrquake","uae4arm","vba_next","vbam",
    "vecx","vice_x128","vice_x64","vice_x64sc","vice_xvic","virtualjaguar",
    "wasm4","x1","xrick","yabasanshiro","yabause"
)

function Show-Help {
    Write-Host "Usage: .\rebuild_cores.ps1 [-List|-Verify|-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Downloads latest aarch64 RetroArch cores and packages them into cores.7z"
    Write-Host ""
    Write-Host "Requires: 7-Zip" -ForegroundColor Yellow
}

function Find-7Zip {
    if (Get-Command 7z -ErrorAction SilentlyContinue) {
        return (Get-Command 7z).Source
    }
    $Paths = @(
        "A:\7-Zip\7z.exe",
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe",
        "$env:LOCALAPPDATA\Programs\7-Zip\7z.exe"
    )
    foreach ($p in $Paths) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Find-Curl {
    # Use curl.exe (not the PowerShell alias) to avoid issues
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        return "curl.exe"
    }
    return $null
}

function Download-Core {
    param(
        [string]$CoreName,
        [string]$CurlPath,
        [string]$szPath
    )

    $SoFile = "${CoreName}_libretro.so"
    $ZipFile = "${SoFile}.zip"
    $Url = "${BaseUrl}/${ZipFile}"
    $Dest = Join-Path $BuildDir $SoFile
    $ZipDest = Join-Path $BuildDir $ZipFile

    if (Test-Path $Dest) {
        Write-Host "  [SKIP] $SoFile (exists)" -ForegroundColor DarkGray
        return "skipped"
    }

    # Download .zip
    & $CurlPath -sS -L --fail -o $ZipDest $Url 2>$null
    if (-not (Test-Path $ZipDest)) {
        Write-Host "  [FAIL] $ZipFile" -ForegroundColor Red
        return "failed"
    }

    # Extract .so from .zip
    & $szPath x -y $ZipDest -o"$BuildDir" 2>$null | Out-Null
    Remove-Item -Path $ZipDest -Force -ErrorAction SilentlyContinue

    if (Test-Path $Dest) {
        Write-Host "  [OK]   $SoFile" -ForegroundColor Green
        return "ok"
    } else {
        Write-Host "  [FAIL] $SoFile (extract error)" -ForegroundColor Red
        return "failed"
    }
}

# --- Main ---

if ($Help) { Show-Help; exit 0 }

if ($List) {
    Write-Host "Required cores ($($RequiredCores.Count) total):" -ForegroundColor Green
    $RequiredCores | Sort-Object | ForEach-Object { Write-Host "  ${_}_libretro.so" }
    exit 0
}

# Find tools
$szPath = Find-7Zip
if (-not $szPath) {
    Write-Host "[ERROR] 7-Zip not found. Install from https://www.7-zip.org/download.html" -ForegroundColor Red
    exit 1
}
Write-Host "[INFO] Found 7-Zip: $szPath" -ForegroundColor Green

$curlPath = Find-Curl
if (-not $curlPath) {
    Write-Host "[ERROR] curl not found. Windows 10+ includes curl.exe" -ForegroundColor Red
    exit 1
}
Write-Host "[INFO] Found curl: $curlPath" -ForegroundColor Green

if ($Verify) {
    if (-not (Test-Path $Output)) {
        Write-Host "[ERROR] cores.7z not found: $Output" -ForegroundColor Red
        exit 1
    }
    Write-Host "[INFO] Verifying cores.7z..." -ForegroundColor Cyan
    & $szPath l $Output | Select-String "\.so$"
    Write-Host ""
    $count = (& $szPath l $Output | Select-String "\.so$" | Measure-Object).Count
    Write-Host "[INFO] $count cores in archive" -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   RetroArch Core Rebuilder" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create build dir (keep existing downloads)
if (-not (Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null }

Write-Host "[STEP] Downloading cores..." -ForegroundColor Blue
Write-Host ""

$ok = 0; $skipped = 0; $failed = 0

foreach ($core in $RequiredCores) {
    $result = Download-Core -CoreName $core -CurlPath $curlPath -szPath $szPath
    switch ($result) {
        "ok"      { $ok++ }
        "skipped" { $skipped++ }
        "failed"  { $failed++ }
    }
}

Write-Host ""
Write-Host "[STEP] Packaging cores.7z..." -ForegroundColor Blue

Push-Location $BuildDir
try {
    & $szPath a -t7z -mx=7 $Output *.so 2>$null | Out-Null

    if (Test-Path $Output) {
        $size = [math]::Round((Get-Item $Output).Length / 1MB, 2)
        Write-Host "[OK] Created: $Output ($size MB, $($ok) cores)" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Failed to create cores.7z" -ForegroundColor Red
        Pop-Location
        exit 1
    }
} finally {
    Pop-Location
}

# Cleanup
Remove-Item -Path $BuildDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   Done!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "   Downloaded: $ok" -ForegroundColor White
Write-Host "   Skipped:    $skipped" -ForegroundColor White
Write-Host "   Failed:     $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "White" })
Write-Host "   Output:     $Output" -ForegroundColor Cyan
Write-Host ""
Write-Host "Upload to: https://github.com/jukaLang/Packages/releases/tag/cores" -ForegroundColor Yellow
