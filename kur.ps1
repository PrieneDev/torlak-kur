# torlak-dash — tek komutluk kurulum önyükleyicisi (Windows). HERKESE AÇIK: içinde sır yoktur.
#   PowerShell (Yönetici olması gerekmez; gerekirse kendini yönetici olarak yeniden başlatır):
#     irm https://raw.githubusercontent.com/PrieneDev/torlak-kur/main/kur.ps1 | iex
#   Parametreli (dosyayı indirip):  .\kur.ps1 [-Hedef C:\Users\ben\torlak-dash] [-Kuru] [-HermesYok] [-YedekDosyasi <yol.tdbk>]
#   (irm | iex ile: $env:TORLAK_KUR_HEDEF / $env:TORLAK_KUR_KURU='1' / $env:TORLAK_KUR_HERMES_YOK='1')
# Yaptığı: winget ile Git + GitHub CLI → gh auth login --web (tarayıcıda GitHub girişi) → gizli repoyu (PrieneDev/torlak-dash)
# indirir/günceller → asıl kurulumu çalıştırır: <hedef>\ops\kur\kur-windows.ps1 -Repo <hedef>.
# Günlük: %ProgramData%\torlak-kur\kur.log  ·  Kaynak: gizli repoda ops/kur/bootstrap/kur.ps1 (ops/kur/yayinla.sh ile buraya kopyalanır)
param(
    [string]$Hedef = '',
    [switch]$Kuru,
    [switch]$HermesYok,
    [string]$YedekDosyasi = ''
)

function Invoke-TorlakKur {
    param([string]$Hedef, [bool]$Kuru, [bool]$HermesYok, [string]$YedekDosyasi, [string]$BuDosya)

    $ErrorActionPreference = 'Stop'
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    $GH_REPO = 'PrieneDev/torlak-dash'
    $KUR_URL = if ($env:TORLAK_KUR_URL) { $env:TORLAK_KUR_URL } else { 'https://raw.githubusercontent.com/PrieneDev/torlak-kur/main/kur.ps1' }
    $KUR_DIR = Join-Path $env:ProgramData 'torlak-kur'
    $LOG = Join-Path $KUR_DIR 'kur.log'

    function Log([string]$m, [string]$tur = 'bilgi') {
        $renk = @{ bilgi = 'Gray'; iyi = 'Green'; uyari = 'Yellow'; hata = 'Red'; baslik = 'Cyan'; kuru = 'Magenta' }[$tur]
        $onek = @{ bilgi = '  '; iyi = '  ✓ '; uyari = '  ! '; hata = '  ✗ '; baslik = "`n▸ "; kuru = '  [kuru] ' }[$tur]
        Write-Host ($onek + $m) -ForegroundColor $renk
        if (-not $Kuru) {
            try {
                if (-not (Test-Path $KUR_DIR)) { New-Item -ItemType Directory -Path $KUR_DIR -Force | Out-Null }
                Add-Content -Path $LOG -Value ('{0:yyyy-MM-dd HH:mm:ss} [kur.ps1] [{1}] {2}' -f (Get-Date), $tur, $m) -Encoding UTF8
            } catch { }
        }
    }
    function Yonetici { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
    function Komut([string]$a) { $c = Get-Command $a -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { $c.Source } else { $null } }
    function Path-Yenile {
        $env:Path = (@([Environment]::GetEnvironmentVariable('Path', 'Machine'), [Environment]::GetEnvironmentVariable('Path', 'User')) | Where-Object { $_ }) -join ';'
        foreach ($ek in @("$env:ProgramFiles\Git\cmd", "$env:ProgramFiles\GitHub CLI")) { if ((Test-Path $ek) -and ($env:Path -notlike "*$ek*")) { $env:Path += ";$ek" } }
    }
    function Calistir([string]$exe, [string[]]$a) {
        $eski = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $o = & $exe @a 2>&1 | ForEach-Object { "$_" }; [pscustomobject]@{ Kod = $LASTEXITCODE; Cikti = ($o -join "`n") } }
        catch { [pscustomobject]@{ Kod = 9999; Cikti = $_.Exception.Message } }
        finally { $ErrorActionPreference = $eski }
    }
    function Tirnak([string]$s) { if ($s -match '[\s"]') { '"' + ($s -replace '"', '\"') + '"' } else { $s } }
    function Etkilesimli([string]$exe, [string[]]$a) { (Start-Process -FilePath $exe -ArgumentList (($a | ForEach-Object { Tirnak $_ }) -join ' ') -NoNewWindow -Wait -PassThru).ExitCode }

    Write-Host ''
    Write-Host "torlak-dash tek komut kurulumu (önyükleyici)$(if ($Kuru) { ' — KURU ÇALIŞMA: hiçbir şey kurulmaz/değiştirilmez' })" -ForegroundColor Cyan

    # 1) Yönetici değilse kendini yönetici olarak yeniden başlat (irm|iex ile çalışınca dosya yok → önce indir)
    if (-not (Yonetici)) {
        if ($Kuru) { Log 'yönetici değil — gerçek çalışmada UAC ile kendini yönetici olarak yeniden başlatır (%ProgramData%\torlak-kur\kur.ps1)' 'kuru' }
        else {
            Log 'Yönetici izni gerekiyor — UAC penceresinde Evet deyin; kurulum yeni (yönetici) pencerede devam eder.' 'uyari'
            $dosya = $BuDosya
            if (-not $dosya -or -not (Test-Path $dosya)) {
                $dosya = Join-Path $KUR_DIR 'kur.ps1'
                try {
                    if (-not (Test-Path $KUR_DIR)) { New-Item -ItemType Directory -Path $KUR_DIR -Force | Out-Null }
                    $t = (Invoke-WebRequest -Uri $KUR_URL -UseBasicParsing).Content
                    if ($t -is [byte[]]) { $t = [Text.Encoding]::UTF8.GetString($t) }
                    # BOM'lu UTF-8: Windows PowerShell 5.1 -File ile Türkçe karakterleri doğru okusun
                    [IO.File]::WriteAllText($dosya, $t.TrimStart([char]0xFEFF), (New-Object Text.UTF8Encoding($true)))
                } catch { Log "Betik indirilemedi ($KUR_URL): $($_.Exception.Message). İnternet bağlantısını kontrol edin." 'hata'; return }
            }
            $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', (Tirnak $dosya))
            if ($Hedef) { $a += @('-Hedef', (Tirnak $Hedef)) }
            if ($HermesYok) { $a += '-HermesYok' }
            if ($YedekDosyasi) { $a += @('-YedekDosyasi', (Tirnak $YedekDosyasi)) }
            try { Start-Process -FilePath 'powershell.exe' -ArgumentList ($a -join ' ') -Verb RunAs | Out-Null; Log 'Yönetici penceresi açıldı — oradan devam edin. Bu pencereyi kapatabilirsiniz.' 'iyi' }
            catch { Log 'Yönetici izni verilmedi. Kurulum yönetici yetkisi ister: PowerShell''i "Yönetici olarak çalıştır" ile açıp komutu yeniden girin.' 'hata' }
            return
        }
    }

    try {
        Log "Başladı: $([Security.Principal.WindowsIdentity]::GetCurrent().Name) · Windows $([Environment]::OSVersion.Version)" 'baslik'
        Path-Yenile

        # 2) Git + GitHub CLI
        if (-not (Komut 'winget') -and -not $Kuru) { throw "winget bulunamadı. Microsoft Store → 'Uygulama Yükleyicisi' (App Installer) güncellenmeli; Windows güncellemelerini yapıp yeniden deneyin." }
        foreach ($p in @(@{ id = 'Git.Git'; ad = 'Git'; k = 'git' }, @{ id = 'GitHub.cli'; ad = 'GitHub CLI'; k = 'gh' })) {
            if (Komut $p.k) { Log "$($p.ad) kurulu" 'iyi'; continue }
            if ($Kuru) { Log "yapılacak: winget install --id $($p.id) -e --silent" 'kuru'; continue }
            Log "$($p.ad) kuruluyor (winget $($p.id))…"
            $r = Calistir 'winget' @('install', '--id', $p.id, '-e', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
            Path-Yenile
            if (-not (Komut $p.k)) { throw "$($p.ad) kurulamadı (winget çıkış $($r.Kod)). Elle: winget install --id $($p.id)" }
            Log "$($p.ad) kuruldu" 'iyi'
        }

        # 3) GitHub girişi (tek giriş; gizli repo için)
        $gh = Komut 'gh'
        if ($gh -and (Calistir $gh @('auth', 'status', '--hostname', 'github.com')).Kod -eq 0) { Log 'GitHub girişi zaten yapılmış' 'iyi' }
        elseif ($Kuru) { Log 'yapılacak: gh auth login --web --git-protocol https --hostname github.com  +  gh auth setup-git' 'kuru' }
        else {
            Log 'GitHub girişi: tarayıcı açılacak; ekrandaki tek kullanımlık kodu girip PrieneDev hesabıyla onaylayın.' 'uyari'
            $k = Etkilesimli $gh @('auth', 'login', '--web', '--git-protocol', 'https', '--hostname', 'github.com')
            if ($k -ne 0) { throw "GitHub girişi tamamlanmadı (çıkış $k). Komutu yeniden çalıştırın." }
            $null = Calistir $gh @('auth', 'setup-git')
            Log 'GitHub girişi tamam' 'iyi'
        }

        # 4) Hedef klasör
        $vars = Join-Path $HOME 'torlak-dash'
        if (-not $Hedef) {
            if ($Kuru) { $Hedef = $vars; Log "soru: Kurulum klasörü [$vars] → varsayılan" 'kuru' }
            else { $c = (Read-Host "  ? Kurulum klasörü [$vars]").Trim(); $Hedef = if ($c) { $c } else { $vars } }
        }
        $Hedef = [IO.Path]::GetFullPath($Hedef)
        Log "Hedef: $Hedef"

        # 5) Clone ya da güncelle
        if (Test-Path (Join-Path $Hedef '.git')) {
            if ($Kuru) { Log "yapılacak: git -C $Hedef pull --ff-only" 'kuru' }
            else {
                $r = Calistir 'git' @('-C', $Hedef, 'pull', '--ff-only')
                if ($r.Kod -eq 0) { Log 'Repo güncellendi (git pull)' 'iyi' } else { Log "git pull yapılamadı (yerel değişiklik?) — mevcut kopyayla devam: $(($r.Cikti -split "`n" | Select-Object -Last 1))" 'uyari' }
            }
        } elseif ((Test-Path $Hedef) -and (Get-ChildItem -Force $Hedef | Select-Object -First 1)) {
            throw "Hedef klasör dolu ama git deposu değil: $Hedef. Boş bir klasör seçin (-Hedef)."
        } elseif ($Kuru) { Log "yapılacak: gh repo clone $GH_REPO $Hedef" 'kuru' }
        else {
            Log "Repo indiriliyor: gh repo clone $GH_REPO $Hedef"
            $k = Etkilesimli $gh @('repo', 'clone', $GH_REPO, $Hedef)
            if ($k -ne 0 -or -not (Test-Path (Join-Path $Hedef '.git'))) { throw "Repo indirilemedi (çıkış $k). GitHub hesabının $GH_REPO erişimi var mı?" }
            Log 'Repo indirildi' 'iyi'
        }

        # 6) Asıl kurulum
        $asil = Join-Path $Hedef 'ops\kur\kur-windows.ps1'
        if (-not (Test-Path $asil)) {
            if ($Kuru) { Log "yapılacak: powershell -File $asil -Repo $Hedef (repo henüz yok)" 'kuru'; Log 'kuru çalışma bitti' 'kuru'; return }
            throw "Asıl kurulum betiği yok: $asil (repo eski mi?)"
        }
        $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $asil, '-Repo', $Hedef)
        if ($Kuru) { $a += '-Kuru' }
        if ($HermesYok) { $a += '-HermesYok' }
        if ($YedekDosyasi) { $a += @('-YedekDosyasi', $YedekDosyasi) }
        Log "Asıl kurulum: $asil" 'baslik'
        $k = Etkilesimli 'powershell.exe' $a
        if ($k -ne 0) { Log "Kurulum yarıda kaldı (çıkış $k). Sorunu giderip aynı komutu yeniden çalıştırın — tamamlanan adımlar atlanır. Günlük: $LOG" 'hata' }
        else { Log 'Önyükleyici bitti.' 'iyi' }
    } catch {
        Log $_.Exception.Message 'hata'
        Log "Kurulum durdu. Komutu yeniden çalıştırabilirsiniz.$(if (-not $Kuru) { " Günlük: $LOG" })" 'uyari'
    }
}

# irm | iex parametre alamaz → ortam değişkenleriyle de verilebilir: TORLAK_KUR_HEDEF, TORLAK_KUR_KURU=1, TORLAK_KUR_HERMES_YOK=1
if (-not $Hedef -and $env:TORLAK_KUR_HEDEF) { $Hedef = $env:TORLAK_KUR_HEDEF }
if ($env:TORLAK_KUR_KURU -eq '1') { $Kuru = [switch]$true }
if ($env:TORLAK_KUR_HERMES_YOK -eq '1') { $HermesYok = [switch]$true }
$__bu = $null
if ($PSCommandPath) { $__bu = $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $__bu = $MyInvocation.MyCommand.Path }
Invoke-TorlakKur -Hedef $Hedef -Kuru ([bool]$Kuru) -HermesYok ([bool]$HermesYok) -YedekDosyasi $YedekDosyasi -BuDosya $__bu
