# ============================================================
# BAHAN BOT RDP - AUTO INSTALLER
# Script ini akan membaca links.json dari GitHub dan otomatis
# mendownload + menginstall semua bahan bot secara silent.
# ============================================================

$ErrorActionPreference = "Stop"
$tempDir = "$env:TEMP\bahanbot"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   BAHAN BOT RDP - AUTO INSTALLER" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Buat folder temporary
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

# 1. Download links.json dari repository
Write-Host "[1/6] Mengambil daftar link terbaru dari GitHub..." -ForegroundColor Yellow
$linksUrl = "https://raw.githubusercontent.com/RusdiEneri/BAHANBOT_RDP/main/links.json"
$linksFile = "$tempDir\links.json"

try {
    Invoke-WebRequest -Uri $linksUrl -OutFile $linksFile -UseBasicParsing
} catch {
    Write-Host "GAGAL mengambil links.json! Pastikan repository publik dan file links.json sudah ada." -ForegroundColor Red
    Read-Host "Tekan Enter untuk keluar"
    exit 1
}

# Baca JSON
$links = Get-Content $linksFile -Raw | ConvertFrom-Json
Write-Host "Daftar link berhasil diambil! Ditemukan $($links.PSObject.Properties.Count) software." -ForegroundColor Green
Write-Host ""

# 2. INSTALL NODE.JS
if ($links.NodeJS) {
    Write-Host "[2/6] Mengunduh & Install Node.js..." -ForegroundColor Yellow
    $nodePath = "$tempDir\node.msi"
    try {
        Invoke-WebRequest -Uri $links.NodeJS -OutFile $nodePath -UseBasicParsing
        Start-Process msiexec.exe -ArgumentList "/i `"$nodePath`" /qn /norestart" -Wait -NoNewWindow
        Write-Host "  -> Node.js berhasil diinstall!" -ForegroundColor Green
    } catch { Write-Host "  -> GAGAL install Node.js: $_" -ForegroundColor Red }
}
Write-Host ""

# 3. INSTALL GIT
if ($links.Git) {
    Write-Host "[3/6] Mengunduh & Install Git..." -ForegroundColor Yellow
    $gitPath = "$tempDir\git.exe"
    try {
        Invoke-WebRequest -Uri $links.Git -OutFile $gitPath -UseBasicParsing
        Start-Process -FilePath $gitPath -ArgumentList "/VERYSILENT /NORESTART /SP- /SUPPRESSMSGBOXES" -Wait -NoNewWindow
        Write-Host "  -> Git berhasil diinstall!" -ForegroundColor Green
    } catch { Write-Host "  -> GAGAL install Git: $_" -ForegroundColor Red }
}
Write-Host ""

# 4. INSTALL FFMPEG
if ($links.FFmpeg) {
    Write-Host "[4/6] Mengunduh & Extract FFmpeg..." -ForegroundColor Yellow
    $ffPath = "$tempDir\ffmpeg.zip"
    $ffInstallDir = "C:\ffmpeg"
    try {
        Invoke-WebRequest -Uri $links.FFmpeg -OutFile $ffPath -UseBasicParsing
        if (Test-Path $ffInstallDir) { Remove-Item -Recurse -Force $ffInstallDir }
        Expand-Archive -Path $ffPath -DestinationPath $ffInstallDir -Force
        $ffBinPath = Get-ChildItem -Path $ffInstallDir -Directory | Select-Object -First 1 | ForEach-Object { Join-Path $_.FullName "bin" }
        if ($ffBinPath -and (Test-Path $ffBinPath)) {
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($currentPath -notlike "*$ffBinPath*") {
                [Environment]::SetEnvironmentVariable("Path", "$currentPath;$ffBinPath", "Machine")
            }
            Write-Host "  -> FFmpeg berhasil diextract dan ditambahkan ke PATH!" -ForegroundColor Green
        }
    } catch { Write-Host "  -> GAGAL install FFmpeg: $_" -ForegroundColor Red }
}
Write-Host ""

# 5. INSTALL IMAGEMAGICK
if ($links.ImageMagick) {
    Write-Host "[5/6] Mengunduh & Install ImageMagick..." -ForegroundColor Yellow
    $imgPath = "$tempDir\imagemagick.exe"
    try {
        Invoke-WebRequest -Uri $links.ImageMagick -OutFile $imgPath -UseBasicParsing
        Start-Process -FilePath $imgPath -ArgumentList "/VERYSILENT /NORESTART /SP- /SUPPRESSMSGBOXES" -Wait -NoNewWindow
        Write-Host "  -> ImageMagick berhasil diinstall!" -ForegroundColor Green
    } catch { Write-Host "  -> GAGAL install ImageMagick: $_" -ForegroundColor Red }
}
Write-Host ""

# 6. INSTALL WINRAR (TAMBAHAN BARU)
if ($links.WinRAR) {
    Write-Host "[6/6] Mengunduh & Install WinRAR..." -ForegroundColor Yellow
    $rarPath = "$tempDir\winrar.exe"
    try {
        Invoke-WebRequest -Uri $links.WinRAR -OutFile $rarPath -UseBasicParsing
        # WinRAR menggunakan flag /S untuk silent install
        Start-Process -FilePath $rarPath -ArgumentList "/S" -Wait -NoNewWindow
        Write-Host "  -> WinRAR berhasil diinstall!" -ForegroundColor Green
    } catch { Write-Host "  -> GAGAL install WinRAR: $_" -ForegroundColor Red }
}
Write-Host ""

# ============================================================
# SELESAI
# ============================================================
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   SEMUA PROSES SELESAI!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "RDP kamu sekarang sudah siap untuk menjalankan Bot." -ForegroundColor White
Write-Host "Software: Node.js, Git, FFmpeg, ImageMagick, WinRAR" -ForegroundColor White

# Bersihkan file temporary
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue

Write-Host "Tekan Enter untuk menutup..." -ForegroundColor Gray
Read-Host
