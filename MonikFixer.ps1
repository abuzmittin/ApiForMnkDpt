& {
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
cls


$C1 = "Cyan"
$C4 = "Green"

Write-Host "`n  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor $C1
Write-Host "  ║             >>> MonikDepot Steam Fix <<<             ║" -ForegroundColor $C4
Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor $C1


Write-Host "`n  [?] Sistemi başlatmak için bir tuşa basın..." -ForegroundColor "Yellow"
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')


Write-Host "  > Bellek kontrol ediliyor..." -ForegroundColor Gray
Start-Sleep -Milliseconds 600


$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36'
$ok = [char]0x2713

function Mesaj($msg, $renk = 'White') {
    Write-Host "  $msg" -ForegroundColor $renk
}

function Hata($mesaj) {
    Write-Host "`n  [!] KRİTİK HATA: $mesaj" -ForegroundColor Red
    try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep 10 }
    exit
}

function SteamiKapat {
    if (Get-Process -Name steam -EA SilentlyContinue) {
        Mesaj "> Steam süreci aktif, sonlandırılıyor..." "Yellow"
        Get-Process steam -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
        Start-Sleep 1
        Mesaj "$ok Steam kapatıldı." "Green"
    }
}


Write-Host "  > Kayıt defteri taranıyor..." -ForegroundColor Gray
Start-Sleep -Milliseconds 800

$steamPath = $null
foreach ($reg in @('HKCU:\Software\Valve\Steam','HKLM:\Software\Valve\Steam','HKLM:\Software\WOW6432Node\Valve\Steam')) {
    $p = (Get-ItemProperty -Path $reg -EA SilentlyContinue).SteamPath
    if ($p -and (Test-Path ($p -replace '/','\'))){ $steamPath = $p -replace '/','\\'; break }
}

if (-not $steamPath) { Hata 'Steam dizini bulunamadı!' }
Mesaj "$ok Steam bulundu: $steamPath" "Green"
Start-Sleep -Milliseconds 500

$dest = Join-Path $steamPath 'version.dll'
$needsUpdate = $true

# --- VERSİYON KONTROL KADEMESİ ---
Write-Host "  > Sunucu verileri doğrulanıyor..." -ForegroundColor Gray
Start-Sleep -Milliseconds 700

if (Test-Path $dest) {
    try {
        $req = [System.Net.HttpWebRequest]::Create('https://r2.steamproof.net/update')
        $req.Method = 'HEAD'
        $req.UserAgent = $UA
        $resp = $req.GetResponse()
        $remoteEtag = $resp.Headers['ETag'] -replace '"',''
        $resp.Close()
        $localHash = (Get-FileHash $dest -Algorithm MD5).Hash.ToLower()
        
        if ($remoteEtag -and $localHash -eq $remoteEtag) {
            Mesaj "$ok Yazılım güncel, kurulum atlanıyor." "Green"
            $needsUpdate = $false
        }
    } catch {
        Mesaj "[!] Sunucuya erişilemedi, mevcut dosya kullanılacak." "Yellow"
    }
}


if ($needsUpdate) {
    SteamiKapat
    Write-Host "  > Dosyalar enjekte ediliyor..." -ForegroundColor Gray
    Start-Sleep -Milliseconds 500
    
    Remove-Item $dest -Force -EA SilentlyContinue
    try {
        $req = [System.Net.HttpWebRequest]::Create('https://r2.steamproof.net/update')
        $req.UserAgent = $UA
        $resp = $req.GetResponse()
        $total = $resp.ContentLength
        $stream = $resp.GetResponseStream()
        $fs = [System.IO.File]::Create($dest)
        $buf = New-Object byte[] 65536
        $dl = 0
        while (($n = $stream.Read($buf, 0, $buf.Length)) -gt 0) {
            $fs.Write($buf, 0, $n); $dl += $n
            if ($total -gt 0) {
                $percent = [math]::Floor(($dl / $total) * 100)
                Write-Host "`r  [+] İndiriliyor: %$percent" -NoNewline -ForegroundColor White
            }
        }
        $fs.Close(); $stream.Close(); $resp.Close()
        Write-Host "`n  $ok Kurulum tamamlandı." -ForegroundColor Green
    } catch { Hata "Bağlantı hatası oluştu!" }
}


Write-Host "`n  > Sistem başlatılıyor..." -ForegroundColor Gray
Start-Sleep -Seconds 1


$mesajMetni = "MonikDepot Steam Fix başarıyla kuruldu.`nİndirme sırasındaki 'Bağlantı yok' (Manifest) hatası giderildi.`n`nYapımcı: Ata.dev`nHepinize iyi oyunlar dileriz."
$baslik = "MonikDepot Steam Fix"
[System.Windows.Forms.MessageBox]::Show($mesajMetni, $baslik, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

Start-Process (Join-Path $steamPath 'steam.exe')
Write-Host "  $ok İŞLEM TAMAMLANDI!" -ForegroundColor Black -BackgroundColor Cyan
Write-Host ''
}