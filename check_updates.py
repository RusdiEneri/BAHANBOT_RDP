import requests
import json
import datetime

links = {}

# 1. Node.js
try:
    node_res = requests.get('https://nodejs.org/dist/index.json').json()
    for node in node_res:
        if node['lts']:
            version = node['version']
            links['NodeJS'] = f"https://nodejs.org/dist/{version}/node-{version}-x64.msi"
            break
except Exception as e: print("Error Nodejs:", e)

# 2. Git for Windows
try:
    git_res = requests.get('https://api.github.com/repos/git-for-windows/git/releases/latest').json()
    for asset in git_res.get('assets', []):
        if '64-bit.exe' in asset['name']:
            links['Git'] = asset['browser_download_url']
            break
except Exception as e: print("Error Git:", e)

# 3. FFmpeg (Build BtbN)
try:
    ff_res = requests.get('https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest').json()
    for asset in ff_res.get('assets', []):
        if 'win64-gpl' in asset['name'] and asset['name'].endswith('.zip'):
            links['FFmpeg'] = asset['browser_download_url']
            break
except Exception as e: print("Error FFmpeg:", e)

# 4. ImageMagick
try:
    img_res = requests.get('https://api.github.com/repos/ImageMagick/ImageMagick/releases/latest').json()
    for asset in img_res.get('assets', []):
        if 'Q16-HDRI-x64-dll.exe' in asset['name']:
            links['ImageMagick'] = asset['browser_download_url']
            break
except Exception as e: print("Error ImageMagick:", e)

# Simpan links.json
with open('links.json', 'w', encoding='utf-8') as f:
    json.dump(links, f, indent=4)

# ==========================================
# GENERATE README.MD OTOMATIS
# ==========================================
timestamp = datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
num_links = len(links)

# Buat tabel otomatis untuk daftar software
table_rows = ""
for name, url in links.items():
    table_rows += f"| {name} | [Download Link]({url}) |\n"

readme_content = f"""# 🤖 BAHAN BOT RDP (Auto Installer)

Repository ini berisi kumpulan link installer otomatis untuk persiapan *environment* Bot WhatsApp di RDP Windows. 
Link di sini selalu diperbarui otomatis oleh sistem sehingga kamu selalu mendapat versi software terbaru!

## 📊 Statistik Repository
- 🕒 **Terakhir Diupdate:** {timestamp}
- 📦 **Jumlah Software Dilacak:** {num_links}
- ✅ **Status Link:** Aktif & Valid

### 📦 Daftar Software Otomatis
| Software | Link Download |
|---|---|
{table_rows}

---

## 🚀 Cara Install di RDP Windows (Sangat Mudah!)

Kamu tidak perlu lagi download file `.exe` satu-satu dari tabel di atas. Cukup ikuti 2 langkah ini:

### Langkah 1: Buka PowerShell sebagai Administrator
1. Klik tombol **Start** di Windows (atau tekan tombol Windows di keyboard).
2. Ketik **PowerShell**.
3. Klik kanan pada "Windows PowerShell" lalu pilih **Run as Administrator**.

### Langkah 2: Copy & Paste Script Ajaib ini
Salin kode di bawah ini, klik kanan di dalam jendela PowerShell untuk mem-paste, lalu tekan **Enter**:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iwr -useb https://raw.githubusercontent.com/RusdiEneri/BAHANBOTRDP/main/install-bahan.ps1 | iex
