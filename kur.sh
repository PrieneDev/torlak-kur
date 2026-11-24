#!/usr/bin/env bash
# torlak-dash — tek komutluk kurulum önyükleyicisi (Linux / CasaOS / homelab). HERKESE AÇIK: içinde sır yoktur.
#   curl -fsSL https://raw.githubusercontent.com/PrieneDev/torlak-kur/main/kur.sh | bash
#   Seçenekli:  curl -fsSL …/kur.sh | bash -s -- [--hedef /DATA/AppData/torlak-dash] [--kuru] [--hermes-yok] [--yedek <yol.tdbk>]
#   (ya da ortam: TORLAK_KUR_HEDEF, TORLAK_KUR_KURU=1, TORLAK_KUR_HERMES_YOK=1)
# Yaptığı: Docker (yoksa get.docker.com) + git + GitHub CLI (Debian/Ubuntu: resmi apt deposu; diğerleri: resmi ikili) →
# gh auth login --web → gizli repo PrieneDev/torlak-dash indirilir/güncellenir → <repo>/ops/kur/kur-linux.sh çalışır.
# Kaynak: gizli repoda ops/kur/bootstrap/kur.sh (ops/kur/yayinla.sh ile buraya kopyalanır).
#
# Not: "curl | bash" ile bash betiği stdin'den okur → her şey main() içinde; sorular /dev/tty'den okunur.
# shellcheck disable=SC1091,SC2015 # /etc/os-release çalışma anında; A && B || dur kalıbı bilerek
set -euo pipefail

main() {
  local GH_REPO="PrieneDev/torlak-dash"
  local HEDEF="${TORLAK_KUR_HEDEF:-}" KURU="${TORLAK_KUR_KURU:-0}" HERMES_YOK="${TORLAK_KUR_HERMES_YOK:-0}" YEDEK=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --hedef) HEDEF="${2:?--hedef bir klasör ister}"; shift 2 ;;
      --kuru) KURU=1; shift ;;
      --hermes-yok) HERMES_YOK=1; shift ;;
      --yedek) YEDEK="${2:?--yedek bir dosya ister}"; shift 2 ;;
      -h|--yardim|--help) sed -n '2,10p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null || true; echo "Seçenekler: --hedef <klasör> --kuru --hermes-yok --yedek <dosya>"; return 0 ;;
      *) echo "Bilinmeyen seçenek: $1" >&2; return 2 ;;
    esac
  done

  local SUDO="" LOG=""
  if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; LOG="${XDG_STATE_HOME:-$HOME/.local/state}/torlak-kur/kur.log"; else LOG="/var/log/torlak-kur.log"; fi

  _log() { [ "$KURU" = 1 ] && return 0; mkdir -p "$(dirname "$LOG")" 2>/dev/null && printf '%s [kur.sh] %s\n' "$(date '+%F %T')" "$*" >>"$LOG" 2>/dev/null || true; }
  bilgi() { printf '  %s\n' "$*"; _log "[bilgi] $*"; }
  iyi() { printf '  \033[32m✓ %s\033[0m\n' "$*"; _log "[iyi] $*"; }
  uyari() { printf '  \033[33m! %s\033[0m\n' "$*"; _log "[uyari] $*"; }
  hata() { printf '  \033[31m✗ %s\033[0m\n' "$*" >&2; _log "[hata] $*"; }
  baslik() { printf '\n\033[36m▸ %s\033[0m\n' "$*"; _log "[baslik] $*"; }
  kuru() { printf '  \033[35m[kuru] %s\033[0m\n' "$*"; }
  var() { command -v "$1" >/dev/null 2>&1; }
  tty_var() { (: </dev/tty) 2>/dev/null; }
  sor() { # sor "soru" varsayılan(e|h) → 0 = evet
    local q="$1" d="${2:-e}" c=""
    if [ "$KURU" = 1 ]; then kuru "soru: $q → varsayılan ($d)"; [ "$d" = e ]; return; fi
    if tty_var; then printf '  ? %s [%s] ' "$q" "$([ "$d" = e ] && echo E/h || echo e/H)" >/dev/tty; read -r c </dev/tty || c=""; fi
    c="$(printf '%s' "${c:-$d}" | tr '[:upper:]' '[:lower:]')"
    [ "$c" = e ] || [ "$c" = evet ] || [ "$c" = y ] || [ "$c" = yes ]
  }
  dur() { hata "$*"; uyari "Kurulum durdu. Sorunu giderip komutu yeniden çalıştırın.${LOG:+ Günlük: $LOG}"; exit 1; }

  printf '\n\033[36mtorlak-dash tek komut kurulumu (Linux önyükleyici)%s\033[0m\n' "$([ "$KURU" = 1 ] && echo ' — KURU ÇALIŞMA: hiçbir şey kurulmaz/değiştirilmez')"
  local os_ad="Linux" casaos=0
  [ -r /etc/os-release ] && os_ad="$(. /etc/os-release && echo "${PRETTY_NAME:-Linux}")"
  { [ -d /var/lib/casaos ] || var casaos; } && casaos=1
  baslik "Başladı: $(id -un) · $os_ad$([ $casaos = 1 ] && echo ' · CasaOS')"
  if [ -n "$SUDO" ] && ! var sudo && [ "$KURU" != 1 ]; then dur "root değilsiniz ve sudo yok — root olarak çalıştırın"; fi

  # 1) Docker
  if var docker; then iyi "Docker kurulu ($(docker --version 2>/dev/null | head -1))"
  elif [ "$KURU" = 1 ]; then kuru "yapılacak: curl -fsSL https://get.docker.com | $SUDO sh  (+ kullanıcıyı docker grubuna ekle)"
  else
    bilgi "Docker kuruluyor (get.docker.com)…"
    curl -fsSL https://get.docker.com | $SUDO sh || dur "Docker kurulamadı"
    [ -n "$SUDO" ] && $SUDO usermod -aG docker "$(id -un)" || true
    $SUDO systemctl enable --now docker 2>/dev/null || true
    iyi "Docker kuruldu"
  fi

  # 2) git + gh
  local apt=0; var apt-get && var dpkg && apt=1
  if ! var git; then
    if [ "$KURU" = 1 ]; then kuru "yapılacak: git kur (paket yöneticisi)"
    elif [ $apt = 1 ]; then $SUDO apt-get update -qq && $SUDO apt-get install -y -qq git ca-certificates curl || dur "git kurulamadı"
    elif var dnf; then $SUDO dnf install -y git || dur "git kurulamadı"
    elif var apk; then $SUDO apk add git || dur "git kurulamadı"
    else dur "git yok ve paket yöneticisi tanınmadı — git'i elle kurun"; fi
  else iyi "git kurulu"; fi
  if var gh; then iyi "GitHub CLI kurulu ($(gh --version | head -1))"
  elif [ "$KURU" = 1 ]; then
    if [ $apt = 1 ]; then kuru "yapılacak: GitHub CLI resmi apt deposu (cli.github.com/packages) + apt install gh"
    else kuru "yapılacak: GitHub CLI resmi ikilisi (github.com/cli/cli/releases, linux_$(uname -m)) → /usr/local/bin/gh"; fi
  elif [ $apt = 1 ]; then
    bilgi "GitHub CLI kuruluyor (resmi apt deposu)…"
    $SUDO mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    $SUDO apt-get update -qq && $SUDO apt-get install -y -qq gh || dur "gh kurulamadı"
    iyi "GitHub CLI kuruldu"
  else
    uyari "Debian/Ubuntu değil — GitHub CLI resmi ikilisi indiriliyor"
    local arch tag tmp
    case "$(uname -m)" in x86_64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; armv7l|armv6l) arch=armv6 ;; *) dur "Mimari tanınmadı: $(uname -m)" ;; esac
    tag="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | grep -m1 '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')"
    [ -n "$tag" ] || dur "gh sürümü bulunamadı"
    tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/cli/cli/releases/download/v${tag}/gh_${tag}_linux_${arch}.tar.gz" | tar -xz -C "$tmp" || dur "gh indirilemedi"
    $SUDO install -m 755 "$tmp/gh_${tag}_linux_${arch}/bin/gh" /usr/local/bin/gh
    rm -rf "$tmp"; iyi "GitHub CLI $tag kuruldu"
  fi

  # 3) GitHub girişi
  if var gh && gh auth status --hostname github.com >/dev/null 2>&1; then iyi "GitHub girişi zaten yapılmış"
  elif [ "$KURU" = 1 ]; then kuru "yapılacak: gh auth login --web --git-protocol https --hostname github.com + gh auth setup-git"
  else
    uyari "GitHub girişi: ekrandaki tek kullanımlık kodu https://github.com/login/device adresinde (telefondan da olur) girin."
    gh auth login --web --git-protocol https --hostname github.com </dev/tty || dur "GitHub girişi tamamlanmadı"
    gh auth setup-git || true
    iyi "GitHub girişi tamam"
  fi

  # 4) Hedef klasör
  local vars="$HOME/torlak-dash"
  [ $casaos = 1 ] && vars="/DATA/AppData/torlak-dash"
  if [ -z "$HEDEF" ]; then
    if [ "$KURU" = 1 ] || ! tty_var; then HEDEF="$vars"; [ "$KURU" = 1 ] && kuru "soru: Kurulum klasörü [$vars] → varsayılan"
    else printf '  ? Kurulum klasörü [%s] ' "$vars" >/dev/tty; read -r HEDEF </dev/tty || true; HEDEF="${HEDEF:-$vars}"; fi
  fi
  bilgi "Hedef: $HEDEF"

  # 5) clone / pull
  if [ -d "$HEDEF/.git" ]; then
    if [ "$KURU" = 1 ]; then kuru "yapılacak: git -C $HEDEF pull --ff-only"
    elif git -C "$HEDEF" pull --ff-only; then iyi "Repo güncellendi"; else uyari "git pull yapılamadı (yerel değişiklik?) — mevcut kopyayla devam"; fi
  elif [ -d "$HEDEF" ] && [ -n "$(ls -A "$HEDEF" 2>/dev/null)" ]; then dur "Hedef klasör dolu ama git deposu değil: $HEDEF (--hedef ile boş klasör verin)"
  elif [ "$KURU" = 1 ]; then kuru "yapılacak: gh repo clone $GH_REPO $HEDEF"
  else
    if [ ! -w "$(dirname "$HEDEF")" ]; then $SUDO mkdir -p "$HEDEF" && $SUDO chown "$(id -u):$(id -g)" "$HEDEF"; fi
    gh repo clone "$GH_REPO" "$HEDEF" || dur "Repo indirilemedi — GitHub hesabının $GH_REPO erişimi var mı?"
    iyi "Repo indirildi"
  fi

  # 6) asıl kurulum
  local asil="$HEDEF/ops/kur/kur-linux.sh"
  local args=(--repo "$HEDEF")
  [ "$KURU" = 1 ] && args+=(--kuru)
  [ "$HERMES_YOK" = 1 ] && args+=(--hermes-yok)
  [ -n "$YEDEK" ] && args+=(--yedek "$YEDEK")
  if [ ! -f "$asil" ]; then
    if [ "$KURU" = 1 ]; then kuru "yapılacak: bash $asil ${args[*]} (repo henüz yok)"; kuru "kuru çalışma bitti"; return 0; fi
    dur "Asıl kurulum betiği yok: $asil"
  fi
  baslik "Asıl kurulum: $asil"
  if tty_var; then bash "$asil" "${args[@]}" </dev/tty; else bash "$asil" "${args[@]}"; fi
}

main "$@"
