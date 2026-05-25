$root = "M:\CD DVD Images\OS\Linux"   # <-- Anpassen!

Get-ChildItem -Path $root -Recurse -Filter *.iso | ForEach-Object {
    $iso = $_.FullName
    $isoBase = [System.IO.Path]::GetFileNameWithoutExtension($iso)

    # Mögliche SHA-Dateinamen:
    # 1) dateiname.iso.sha256
    # 2) dateiname.sha256
    $shaCandidates = @(
        "$iso.sha256"
        (Join-Path $_.DirectoryName "$isoBase.sha256")
    )

    # Existierende SHA-Datei finden
    $shaFile = $shaCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $shaFile) {
        Write-Host "❌ Keine passende SHA256-Datei gefunden für $iso" -ForegroundColor Yellow
        return
    }

    # SHA256-Zeile lesen
    $line = (Get-Content $shaFile | Select-Object -First 1).Trim()

    # Hash extrahieren (erste 64 Hex-Zeichen)
    if ($line -match "^[0-9a-fA-F]{64}") {
        $expectedHash = $matches[0]
    } else {
        Write-Host "❌ Ungültiges SHA256-Format in $shaFile" -ForegroundColor Red
        return
    }

    # Tatsächlichen Hash berechnen
    $actualHash = (Get-FileHash -Path $iso -Algorithm SHA256).Hash

    if ($expectedHash.ToLower() -eq $actualHash.ToLower()) {
        Write-Host "✔  OK: $($_.Name) ist gültig" -ForegroundColor Green
    } else {
        Write-Host "❌ FEHLER: $($_.Name) ist beschädigt oder falsch!" -ForegroundColor Red
        Write-Host "   Erwartet:    $expectedHash"
        Write-Host "   Tatsächlich: $actualHash"
    }
}
