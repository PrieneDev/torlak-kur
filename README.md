# torlak-kur

**torlak-dash** için tek komutluk kurulum önyükleyicisi. Bu repo herkese açıktır ve **sır içermez**; asıl kurulum gizli repodadır
(GitHub girişinden sonra indirilir).

| Makine | Komut |
|---|---|
| Windows 10/11 (PowerShell) | `irm https://raw.githubusercontent.com/PrieneDev/torlak-kur/main/kur.ps1 \| iex` |
| Linux / CasaOS | `curl -fsSL https://raw.githubusercontent.com/PrieneDev/torlak-kur/main/kur.sh \| bash` |

Ne yapar: Git + GitHub CLI kurar → `gh auth login --web` (tarayıcıda GitHub girişi) → gizli repoyu indirir → asıl kurulumu
başlatır (programlar, Docker, yedekten geri yükleme, panel, Denetci, Hermes, Tailscale/RustDesk). Elinizde **Kurtarma kartı**
(kurtarma kodu + yedek parolası) olsun.

Seçenekler: Windows `-Hedef <klasör> -Kuru -HermesYok -YedekDosyasi <yedek.tdbk>` (irm|iex ile: `$env:TORLAK_KUR_HEDEF`,
`$env:TORLAK_KUR_KURU='1'`); Linux `bash -s -- --hedef <klasör> --kuru --hermes-yok --yedek <yedek.tdbk>`.
`-Kuru` / `--kuru` hiçbir şey kurmadan ne yapılacağını gösterir.

Bu dosyalar gizli repodaki `ops/kur/bootstrap/` klasöründen `ops/kur/yayinla.sh` ile kopyalanır — burada elle düzenlemeyin.
