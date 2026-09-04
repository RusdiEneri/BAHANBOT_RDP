# ============================================================
# BAHAN BOT RDP - ULTIMATE AUTO INSTALLER v2.0
# Multi-Bahasa Support: Node.js, Python, Go, Rust, Java, PHP
# Author: RusdiEneri
# ============================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "BAHAN BOT RDP - Installer"

# Konfigurasi Global
$REPO_URL = "https://raw.githubusercontent.com/RusdiEneri/BAHANBOT_RDP/main/links.json"
$TEMP_DIR = "$env:TEMP\bahanbot_$(Get-Date -Format 'yyyyMMddHHmmss')"
$LOG_FILE = "$env:TEMP\bahanbot_install.log"
$RESULTS = @()

# ============================================================
# FUNGSI HELPER
# ============================================================

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                        ║" -ForegroundColor Cyan
    Write-Host "  ║      🤖 BAHAN BOT RDP - ULTIMATE AUTO INSTALLER        ║" -ForegroundColor Cyan
    Write-Host "  ║           Multi-Bahasa Support (v2.0)                  ║" -ForegroundColor Cyan
    Write-Host "  ║                                                        ║" -ForegroundColor Cyan
    Write-Host "  ╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Step, [string]$Message, [string]$Color = "Yellow")
    Write-Host "[$Step] " -ForegroundColor $Color -NoNewline
    Write-Host $Message
}

function Write-Result {
    param([string]$Name, [string]$Status, [string]$Detail = "")
    $color = if ($Status -eq "SUKSES") { "Green" } elseif ($Status -eq "SKIP") { "Yellow" } else { "Red" }
    $icon = if ($Status -eq "SUKSES") { "✓" } elseif ($Status -eq "SKIP") { "⊘" } else { "✗" }
    Write-Host "  $icon " -ForegroundColor $color -NoNewline
    Write-Host "$Name " -NoNewline
    if ($Detail) { Write-Host "($Detail)" -ForegroundColor Gray } else { Write-Host "" }
}

function Download-File {
    param([string]$Url, [string]$Destination, [int]$MaxRetries = 3)
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-Verbose "Download attempt $i of $MaxRetries"
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $Destination)
            if (Test-Path $Destination) { return $true }
        } catch {
            Write-Verbose "Attempt $i failed: $($_.Exception.Message)"
            if ($i -eq $MaxRetries) { throw "Download gagal setelah $MaxRetries percobaan" }
            Start-Sleep -Seconds 2
        }
    }
    return $false
}

function Install-MSI {
    param([string]$Path, [string]$Arguments = "/qn /norestart")
    $process = Start-Process msiexec.exe -ArgumentList "/i `"$Path`" $Arguments" -Wait -PassThru -NoNewWindow
    return $process.ExitCode -eq 0 -or $process.ExitCode -eq 3010
}

function Install-Exe {
    param([string]$Path, [string]$Arguments)
    $process = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    return $process.ExitCode -eq 0
}

function Refresh-Path {
    # Refresh PATH di session saat ini agar software baru langsung bisa dipakai
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
    Write-Verbose "PATH di-refresh dari registry"
}

function Add-ToPath {
    param([string]$NewPath, [string]$Scope = "Machine")
    $currentPath = [Environment]::GetEnvironmentVariable("Path", $Scope)
    if ($currentPath -notlike "*$NewPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$NewPath", $Scope)
        Refresh-Path
        return $true
    }
    return $false
}

function Test-Installed {
    param([string]$Command)
    try {
        $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    } catch { return $false }
    return $false
}

function Get-SoftwareLink {
    param($Links, [string]$Key)
    # Helper untuk akses key JSON dengan nama yang ada spasi/titik
    foreach ($prop in $Links.PSObject.Properties) {
        if ($prop.Name -like "*$Key*") { return $prop.Value }
    }
    return $null
}

# ============================================================
# MENU UTAMA
# ============================================================

Write-Banner

Write-Host "  📋 Pilih Paket Instalasi:" -ForegroundColor White
Write-Host ""
Write-Host "  [1] " -ForegroundColor Cyan -NoNewline
Write-Host "🚀 PAKET LENGKAP - Semua Software (Disarankan)"
Write-Host "  [2] " -ForegroundColor Cyan -NoNewline
Write-Host "📱 Bot Node.js (Baileys/WhatsApp)"
Write-Host "  [3] " -ForegroundColor Cyan -NoNewline
Write-Host "🐍 Bot Python (PyWa/Telegram)"
Write-Host "  [4] " -ForegroundColor Cyan -NoNewline
Write-Host "🔥 Bot Go (High Performance)"
Write-Host "  [5] " -ForegroundColor Cyan -NoNewline
Write-Host "☕ Bot Java (Enterprise)"
Write-Host "  [6] " -ForegroundColor Cyan -NoNewline
Write-Host "🐘 Bot PHP"
Write-Host "  [7] " -ForegroundColor Cyan -NoNewline
Write-Host "⚙️  Bot Rust"
Write-Host "  [8] " -ForegroundColor Cyan -NoNewline
Write-Host "🔧 Development Tools Only (VS Code, Git, Postman)"
Write-Host "  [9] " -ForegroundColor Cyan -NoNewline
Write-Host "🛠️  Database Only (MongoDB, Redis)"
Write-Host "  [0] " -ForegroundColor Cyan -NoNewline
Write-Host "❌ Keluar"
Write-Host ""

do {
    $pilihan = Read-Host "  Masukkan pilihan (0-9)"
} while ($pilihan -notmatch "^[0-9]$")

if ($pilihan -eq "0") {
    Write-Host "  👋 Installer dibatalkan." -ForegroundColor Yellow
    exit
}

# ============================================================
# DOWNLOAD LINKS.JSON
# ============================================================

New-Item -ItemType Directory -Force -Path $TEMP_DIR | Out-Null

Write-Step "INFO" "Mengambil daftar link terbaru dari repository..."
$linksFile = "$TEMP_DIR\links.json"

try {
    Invoke-WebRequest -Uri $REPO_URL -OutFile $linksFile -UseBasicParsing
    $links = Get-Content $linksFile -Raw | ConvertFrom-Json
    $totalLinks = $links.PSObject.Properties.Count
    Write-Host "  ✓ Berhasil! Ditemukan $totalLinks software." -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "  ✗ GAGAL mengambil links.json!" -ForegroundColor Red
    Write-Host "  Detail: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host "  Pastikan repository publik dan file links.json ada." -ForegroundColor Yellow
    Read-Host "  Tekan Enter untuk keluar"
    exit 1
}

# ============================================================
# DEFINISI PAKET INSTALASI
# ============================================================

$packages = @{
    "1" = @("Node", "Python", "Go", "Rust", "Java", "PHP", "Ruby", "Git", "FFmpeg", "ImageMagick", "VS Code", "MongoDB", "Redis", "Docker", "WinRAR", "Chocolatey", "Postman", "7-Zip", "ngrok", "Cloudflared")
    "2" = @("Node", "Git", "FFmpeg", "ImageMagick", "VS Code", "Postman", "ngrok")
    "3" = @("Python", "Git", "FFmpeg", "ImageMagick", "VS Code", "Postman", "ngrok")
    "4" = @("Go", "Git", "FFmpeg", "ImageMagick", "VS Code", "Postman", "ngrok")
    "5" = @("Java", "Git", "FFmpeg", "ImageMagick", "VS Code", "Postman", "ngrok")
    "6" = @("PHP", "Git", "FFmpeg", "ImageMagick", "VS Code", "Postman", "ngrok")
    "7" = @("Rust", "Git", "FFmpeg", "ImageMagick", "VS Code", "Postman", "ngrok")
    "8" = @("VS Code", "Git", "Postman", "Docker", "Chocolatey")
    "9" = @("MongoDB", "Redis", "Docker")
}

$selectedPackages = $packages[$pilihan]
Write-Step "INFO" "Akan menginstall $($selectedPackages.Count) software..." -Color "Magenta"
Write-Host ""

# ============================================================
# PROSES INSTALASI
# ============================================================

$stepNumber = 0
$totalSteps = $selectedPackages.Count

# 1. NODE.JS
if ($selectedPackages -contains "Node") {
    $stepNumber++
    $nodeUrl = Get-SoftwareLink $links "Node"
    if ($nodeUrl) {
        Write-Step "$stepNumber/$totalSteps" "Node.js"
        if (Test-Installed "node") {
            Write-Result "Node.js" "SKIP" "Sudah terinstall"
        } else {
            $nodePath = "$TEMP_DIR\node.msi"
            try {
                Download-File $nodeUrl $nodePath | Out-Null
                if (Install-MSI $nodePath) {
                    Write-Result "Node.js" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "Node.js" "GAGAL" $_.Exception.Message }
        }
    }
}

# 2. PYTHON
if ($selectedPackages -contains "Python") {
    $stepNumber++
    $pyUrl = Get-SoftwareLink $links "Python"
    if ($pyUrl) {
        Write-Step "$stepNumber/$totalSteps" "Python"
        if (Test-Installed "python") {
            Write-Result "Python" "SKIP" "Sudah terinstall"
        } else {
            $pyPath = "$TEMP_DIR\python.exe"
            try {
                Download-File $pyUrl $pyPath | Out-Null
                # Silent install Python dengan opsi add to PATH
                if (Install-Exe $pyPath "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0") {
                    Write-Result "Python" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "Python" "GAGAL" $_.Exception.Message }
        }
    }
}

# 3. GO
if ($selectedPackages -contains "Go") {
    $stepNumber++
    $goUrl = Get-SoftwareLink $links "Go"
    if ($goUrl) {
        Write-Step "$stepNumber/$totalSteps" "Go"
        if (Test-Installed "go") {
            Write-Result "Go" "SKIP" "Sudah terinstall"
        } else {
            $goPath = "$TEMP_DIR\go.msi"
            try {
                Download-File $goUrl $goPath | Out-Null
                if (Install-MSI $goPath) {
                    Write-Result "Go" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "Go" "GAGAL" $_.Exception.Message }
        }
    }
}

# 4. RUST
if ($selectedPackages -contains "Rust") {
    $stepNumber++
    $rustUrl = Get-SoftwareLink $links "Rust"
    if ($rustUrl) {
        Write-Step "$stepNumber/$totalSteps" "Rust"
        if (Test-Installed "rustc") {
            Write-Result "Rust" "SKIP" "Sudah terinstall"
        } else {
            $rustPath = "$TEMP_DIR\rust.msi"
            try {
                Download-File $rustUrl $rustPath | Out-Null
                if (Install-MSI $rustPath) {
                    Write-Result "Rust" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "Rust" "GAGAL" $_.Exception.Message }
        }
    }
}

# 5. JAVA
if ($selectedPackages -contains "Java") {
    $stepNumber++
    $javaUrl = Get-SoftwareLink $links "Java"
    if ($javaUrl) {
        Write-Step "$stepNumber/$totalSteps" "Java JDK"
        if (Test-Installed "java") {
            Write-Result "Java" "SKIP" "Sudah terinstall"
        } else {
            $javaPath = "$TEMP_DIR\java.msi"
            try {
                Download-File $javaUrl $javaPath | Out-Null
                if (Install-MSI $javaPath) {
                    Write-Result "Java" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "Java" "GAGAL" $_.Exception.Message }
        }
    }
}

# 6. PHP
if ($selectedPackages -contains "PHP") {
    $stepNumber++
    $phpUrl = Get-SoftwareLink $links "PHP"
    if ($phpUrl) {
        Write-Step "$stepNumber/$totalSteps" "PHP"
        $phpDir = "C:\php"
        if (Test-Path "$phpDir\php.exe") {
            Write-Result "PHP" "SKIP" "Sudah terinstall"
        } else {
            $phpPath = "$TEMP_DIR\php.zip"
            try {
                Download-File $phpUrl $phpPath | Out-Null
                New-Item -ItemType Directory -Force -Path $phpDir | Out-Null
                Expand-Archive -Path $phpPath -DestinationPath $phpDir -Force
                if (Add-ToPath $phpDir) {
                    Write-Result "PHP" "SUKSES" "Ditambahkan ke PATH"
                } else {
                    Write-Result "PHP" "SUKSES"
                }
                Refresh-Path
            } catch { Write-Result "PHP" "GAGAL" $_.Exception.Message }
        }
    }
}

# 7. RUBY
if ($selectedPackages -contains "Ruby") {
    $stepNumber++
    $rubyUrl = Get-SoftwareLink $links "Ruby"
    if ($rubyUrl) {
        Write-Step "$stepNumber/$totalSteps" "Ruby"
        if (Test-Installed "ruby") {
            Write-Result "Ruby" "SKIP" "Sudah terinstall"
        } else {
            $rubyPath = "$TEMP_DIR\ruby.exe"
            try {
                Download-File $rubyUrl $rubyPath | Out-Null
                if (Install-Exe $rubyPath "/VERYSILENT /NORESTART /SP- /SUPPRESSMSGBOXES") {
                    Write-Result "Ruby" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "Ruby" "GAGAL" $_.Exception.Message }
        }
    }
}

# 8. GIT
if ($selectedPackages -contains "Git") {
    $stepNumber++
    $gitUrl = Get-SoftwareLink $links "Git"
    if ($gitUrl) {
        Write-Step "$stepNumber/$totalSteps" "Git"
        if (Test-Installed "git") {
            Write-Result "Git" "SKIP" "Sudah terinstall"
        } else {
            $gitPath = "$TEMP_DIR\git.exe"
            try {
                Download-File $gitUrl $gitPath | Out-Null
                # Git pakai Inno Setup - gunakan silent yang benar
                if (Install-Exe $gitPath "/VERYSILENT /NORESTART /SP- /SUPPRESSMSGBOXES /COMPONENTS=`"icons,ext\reg\shellhere,assoc,assoc_sh`"") {
                    Write-Result "Git" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "Git" "GAGAL" $_.Exception.Message }
        }
    }
}

# 9. FFMPEG
if ($selectedPackages -contains "FFmpeg") {
    $stepNumber++
    $ffUrl = Get-SoftwareLink $links "FFmpeg"
    if ($ffUrl) {
        Write-Step "$stepNumber/$totalSteps" "FFmpeg"
        $ffDir = "C:\ffmpeg"
        if (Test-Path "$ffDir\bin\ffmpeg.exe") {
            Write-Result "FFmpeg" "SKIP" "Sudah terinstall"
        } else {
            $ffPath = "$TEMP_DIR\ffmpeg.zip"
            try {
                Download-File $ffUrl $ffPath | Out-Null
                if (Test-Path $ffDir) { Remove-Item -Recurse -Force $ffDir }
                Expand-Archive -Path $ffPath -DestinationPath $ffDir -Force
                
                # Cari bin folder dengan regex yang lebih robust
                $ffmpegSubDir = Get-ChildItem -Path $ffDir -Directory | Select-Object -First 1
                if ($ffmpegSubDir) {
                    $binPath = Join-Path $ffmpegSubDir.FullName "bin"
                    if (Test-Path $binPath) {
                        if (Add-ToPath $binPath) {
                            Write-Result "FFmpeg" "SUKSES" "PATH diperbarui"
                        } else {
                            Write-Result "FFmpeg" "SUKSES"
                        }
                        Refresh-Path
                    } else { throw "Folder bin tidak ditemukan" }
                } else { throw "Subfolder tidak ditemukan" }
            } catch { Write-Result "FFmpeg" "GAGAL" $_.Exception.Message }
        }
    }
}

# 10. IMAGEMAGICK
if ($selectedPackages -contains "ImageMagick") {
    $stepNumber++
    $imgUrl = Get-SoftwareLink $links "ImageMagick"
    if ($imgUrl) {
        Write-Step "$stepNumber/$totalSteps" "ImageMagick"
        if (Test-Installed "magick") {
            Write-Result "ImageMagick" "SKIP" "Sudah terinstall"
        } else {
            $imgPath = "$TEMP_DIR\imagemagick.exe"
            try {
                Download-File $imgUrl $imgPath | Out-Null
                # ImageMagick pakai Inno Setup
                if (Install-Exe $imgPath "/VERYSILENT /NORESTART /SP- /SUPPRESSMSGBOXES /TASKS=`"modifypath`"") {
                    Write-Result "ImageMagick" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "ImageMagick" "GAGAL" $_.Exception.Message }
        }
    }
}

# 11. VS CODE
if ($selectedPackages -contains "VS Code") {
    $stepNumber++
    $vscodeUrl = Get-SoftwareLink $links "VS Code"
    if ($vscodeUrl) {
        Write-Step "$stepNumber/$totalSteps" "VS Code"
        if (Test-Installed "code") {
            Write-Result "VS Code" "SKIP" "Sudah terinstall"
        } else {
            $vscodePath = "$TEMP_DIR\vscode.exe"
            try {
                Download-File $vscodeUrl $vscodePath | Out-Null
                # VS Code pakai Inno Setup
                if (Install-Exe $vscodePath "/VERYSILENT /NORESTART /MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,addtopath") {
                    Write-Result "VS Code" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "VS Code" "GAGAL" $_.Exception.Message }
        }
    }
}

# 12. MONGODB
if ($selectedPackages -contains "MongoDB") {
    $stepNumber++
    $mongoUrl = Get-SoftwareLink $links "MongoDB"
    if ($mongoUrl) {
        Write-Step "$stepNumber/$totalSteps" "MongoDB"
        $mongoDir = "C:\mongodb"
        if (Test-Path "$mongoDir\bin\mongod.exe") {
            Write-Result "MongoDB" "SKIP" "Sudah terinstall"
        } else {
            $mongoPath = "$TEMP_DIR\mongodb.zip"
            try {
                Download-File $mongoUrl $mongoPath | Out-Null
                New-Item -ItemType Directory -Force -Path $mongoDir | Out-Null
                Expand-Archive -Path $mongoPath -DestinationPath $mongoDir -Force
                $mongoSubDir = Get-ChildItem -Path $mongoDir -Directory | Select-Object -First 1
                if ($mongoSubDir) {
                    $binPath = Join-Path $mongoSubDir.FullName "bin"
                    if (Test-Path $binPath) {
                        if (Add-ToPath $binPath) {
                            Write-Result "MongoDB" "SUKSES" "PATH diperbarui"
                        } else {
                            Write-Result "MongoDB" "SUKSES"
                        }
                        Refresh-Path
                    }
                }
            } catch { Write-Result "MongoDB" "GAGAL" $_.Exception.Message }
        }
    }
}

# 13. REDIS
if ($selectedPackages -contains "Redis") {
    $stepNumber++
    $redisUrl = Get-SoftwareLink $links "Redis"
    if ($redisUrl) {
        Write-Step "$stepNumber/$totalSteps" "Redis"
        if (Test-Installed "redis-server") {
            Write-Result "Redis" "SKIP" "Sudah terinstall"
        } else {
            $redisPath = "$TEMP_DIR\redis.msi"
            try {
                Download-File $redisUrl $redisPath | Out-Null
                if (Install-MSI $redisPath) {
                    Write-Result "Redis" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "Redis" "GAGAL" $_.Exception.Message }
        }
    }
}

# 14. DOCKER DESKTOP
if ($selectedPackages -contains "Docker") {
    $stepNumber++
    $dockerUrl = Get-SoftwareLink $links "Docker"
    if ($dockerUrl) {
        Write-Step "$stepNumber/$totalSteps" "Docker Desktop"
        if (Test-Installed "docker") {
            Write-Result "Docker" "SKIP" "Sudah terinstall"
        } else {
            $dockerPath = "$TEMP_DIR\docker.exe"
            try {
                Download-File $dockerUrl $dockerPath | Out-Null
                # Docker butuh quiet mode
                if (Install-Exe $dockerPath "install --quiet --accept-license") {
                    Write-Result "Docker" "SUKSES" "Perlu restart RDP"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "Docker" "GAGAL" $_.Exception.Message }
        }
    }
}

# 15. WINRAR
if ($selectedPackages -contains "WinRAR") {
    $stepNumber++
    $rarUrl = Get-SoftwareLink $links "WinRAR"
    if ($rarUrl) {
        Write-Step "$stepNumber/$totalSteps" "WinRAR"
        if (Test-Installed "WinRAR") {
            Write-Result "WinRAR" "SKIP" "Sudah terinstall"
        } else {
            $rarPath = "$TEMP_DIR\winrar.exe"
            try {
                Download-File $rarUrl $rarPath | Out-Null
                # WinRAR pakai NSIS - flag /S (capital S)
                if (Install-Exe $rarPath "/S") {
                    Write-Result "WinRAR" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "WinRAR" "GAGAL" $_.Exception.Message }
        }
    }
}

# 16. CHOCOLATEY
if ($selectedPackages -contains "Chocolatey") {
    $stepNumber++
    $chocoUrl = Get-SoftwareLink $links "Chocolatey"
    if ($chocoUrl) {
        Write-Step "$stepNumber/$totalSteps" "Chocolatey"
        if (Test-Installed "choco") {
            Write-Result "Chocolatey" "SKIP" "Sudah terinstall"
        } else {
            try {
                # Install Chocolatey dari script resmi
                Set-ExecutionPolicy Bypass -Scope Process -Force
                $chocoScript = "$TEMP_DIR\install-choco.ps1"
                Download-File $chocoUrl $chocoScript | Out-Null
                & $chocoScript | Out-Null
                Refresh-Path
                Write-Result "Chocolatey" "SUKSES"
            } catch { Write-Result "Chocolatey" "GAGAL" $_.Exception.Message }
        }
    }
}

# 17. POSTMAN
if ($selectedPackages -contains "Postman") {
    $stepNumber++
    $postUrl = Get-SoftwareLink $links "Postman"
    if ($postUrl) {
        Write-Step "$stepNumber/$totalSteps" "Postman"
        if (Test-Path "$env:LOCALAPPDATA\Postman\Postman.exe") {
            Write-Result "Postman" "SKIP" "Sudah terinstall"
        } else {
            $postPath = "$TEMP_DIR\postman.exe"
            try {
                Download-File $postUrl $postPath | Out-Null
                # Postman pakai Squirrel
                if (Install-Exe $postPath "--silent") {
                    Write-Result "Postman" "SUKSES"
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "Postman" "GAGAL" $_.Exception.Message }
        }
    }
}

# 18. 7-ZIP
if ($selectedPackages -contains "7-Zip") {
    $stepNumber++
    $zipUrl = Get-SoftwareLink $links "7-Zip"
    if ($zipUrl) {
        Write-Step "$stepNumber/$totalSteps" "7-Zip"
        if (Test-Installed "7z") {
            Write-Result "7-Zip" "SKIP" "Sudah terinstall"
        } else {
            $zipPath = "$TEMP_DIR\7zip.exe"
            try {
                Download-File $zipUrl $zipPath | Out-Null
                # 7-Zip pakai NSIS - flag /S
                if (Install-Exe $zipPath "/S") {
                    Write-Result "7-Zip" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "7-Zip" "GAGAL" $_.Exception.Message }
        }
    }
}

# 19. NGROK
if ($selectedPackages -contains "ngrok") {
    $stepNumber++
    $ngrokUrl = Get-SoftwareLink $links "ngrok"
    if ($ngrokUrl) {
        Write-Step "$stepNumber/$totalSteps" "ngrok"
        $ngrokDir = "C:\ngrok"
        if (Test-Path "$ngrokDir\ngrok.exe") {
            Write-Result "ngrok" "SKIP" "Sudah terinstall"
        } else {
            $ngrokPath = "$TEMP_DIR\ngrok.zip"
            try {
                Download-File $ngrokUrl $ngrokPath | Out-Null
                New-Item -ItemType Directory -Force -Path $ngrokDir | Out-Null
                Expand-Archive -Path $ngrokPath -DestinationPath $ngrokDir -Force
                if (Add-ToPath $ngrokDir) {
                    Write-Result "ngrok" "SUKSES" "PATH diperbarui"
                } else {
                    Write-Result "ngrok" "SUKSES"
                }
                Refresh-Path
            } catch { Write-Result "ngrok" "GAGAL" $_.Exception.Message }
        }
    }
}

# 20. CLOUDFLARED
if ($selectedPackages -contains "Cloudflared") {
    $stepNumber++
    $cloudUrl = Get-SoftwareLink $links "Cloudflared"
    if ($cloudUrl) {
        Write-Step "$stepNumber/$totalSteps" "Cloudflared"
        if (Test-Installed "cloudflared") {
            Write-Result "Cloudflared" "SKIP" "Sudah terinstall"
        } else {
            $cloudPath = "$TEMP_DIR\cloudflared.msi"
            try {
                Download-File $cloudUrl $cloudPath | Out-Null
                if (Install-MSI $cloudPath) {
                    Write-Result "Cloudflared" "SUKSES"
                    Refresh-Path
                } else { throw "Exit code tidak normal" }
            } catch { Write-Result "Cloudflared" "GAGAL" $_.Exception.Message }
        }
    }
}

# ============================================================
# SUMMARY LAPORAN
# ============================================================

Write-Host ""
Write-Host "  ════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  📊 RINGKASAN INSTALASI" -ForegroundColor Cyan
Write-Host "  ════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Verifikasi software yang terinstall
$installed = @{
    "Node.js" = Test-Installed "node"
    "Python" = Test-Installed "python"
    "Go" = Test-Installed "go"
    "Rust" = Test-Installed "rustc"
    "Java" = Test-Installed "java"
    "PHP" = Test-Installed "php"
    "Git" = Test-Installed "git"
    "FFmpeg" = Test-Installed "ffmpeg"
    "ImageMagick" = Test-Installed "magick"
    "VS Code" = Test-Installed "code"
    "WinRAR" = (Test-Path "C:\Program Files\WinRAR\WinRAR.exe") -or (Test-Path "C:\Program Files (x86)\WinRAR\WinRAR.exe")
    "7-Zip" = (Test-Path "C:\Program Files\7-Zip\7z.exe")
    "Chocolatey" = Test-Installed "choco"
    "ngrok" = Test-Installed "ngrok"
    "Cloudflared" = Test-Installed "cloudflared"
    "Docker" = Test-Installed "docker"
    "MongoDB" = Test-Installed "mongod"
    "Redis" = Test-Installed "redis-server"
}

$suksesCount = 0
$gagalCount = 0
foreach ($sw in $installed.GetEnumerator()) {
    if ($sw.Value) {
        Write-Host "  ✓ " -ForegroundColor Green -NoNewline
        Write-Host $sw.Key
        $suksesCount++
    }
}

Write-Host ""
Write-Host "  🎉 Total Software Terinstall: " -NoNewline
Write-Host "$suksesCount" -ForegroundColor Green -NoNewline
Write-Host " dari $($installed.Count) yang di-check"
Write-Host ""

# Cleanup
try {
    if (Test-Path $TEMP_DIR) {
        Remove-Item -Recurse -Force $TEMP_DIR -ErrorAction SilentlyContinue
    }
} catch {}

Write-Host "  ════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  💡 TIPS:" -ForegroundColor Yellow
Write-Host "  • Restart PowerShell/CMD agar PATH baru aktif" -ForegroundColor White
Write-Host "  • Untuk cek versi: node -v, python --version, go version" -ForegroundColor White
Write-Host "  • Untuk ngrok, jalankan: ngrok config add-authtoken <TOKEN>" -ForegroundColor White
Write-Host ""

Write-Host "  Tekan Enter untuk menutup..." -ForegroundColor Gray
Read-Host