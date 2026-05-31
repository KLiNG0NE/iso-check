$root = "C:\Pfad\zu\ISO"   # <-- Anpassen!

Get-ChildItem -Path $root -Recurse -Filter *.iso | ForEach-Object {
    $iso = $_.FullName
    $dir = $_.DirectoryName
    $base = [System.IO.Path]::GetFileNameWithoutExtension($iso)

    # Kandidaten in Priorität: SHA256 → SHA1 → MD5
    $hashTypes = @(
        @{ Algo = "SHA256"; Ext = "sha256" },
        @{ Algo = "SHA1";   Ext = "sha1"   },
        @{ Algo = "MD5";    Ext = "md5"    }
    )

    $selected = $null

    foreach ($ht in $hashTypes) {
        $candidates = @(
            Join-Path $dir ($_.Name + "." + $ht.Ext)      # datei.iso.sha256
            Join-Path $dir ($base + "." + $ht.Ext)        # datei.sha256
        )

        foreach ($c in $candidates) {
            if (Test-Path $c) {
                $selected = @{
                    File = $c
                    Algo = $ht.Algo
                }
                break
            }
        }
        if ($selected) { break }
    }

    if (-not $selected) {
        Write-Host "❌ Keine Hash-Datei (SHA256/SHA1/MD5) gefunden für $iso" -ForegroundColor Yellow
        return
    }

    # Hash-Zeile lesen
    $line = (Get-Content $selected.File | Select-Object -First 1).Trim()

    # Hash extrahieren (erste gültige Hex-Zeichenfolge)
    switch ($selected.Algo) {
        "SHA256" { $regex = "^[0-9a-fA-F]{64}" }
        "SHA1"   { $regex = "^[0-9a-fA-F]{40}" }
        "MD5"    { $regex = "^[0-9a-fA-F]{32}" }
    }

    if ($line -match $regex) {
        $expectedHash = $matches[0]
    } else {
        Write-Host "❌ Ungültiges Format in $($selected.File)" -ForegroundColor Red
        return
    }

    # Tatsächlichen Hash berechnen
    $actualHash = (Get-FileHash -Path $iso -Algorithm $selected.Algo).Hash

    if ($expectedHash.ToLower() -eq $actualHash.ToLower()) {
        Write-Host "✔  OK ($($selected.Algo)): $($_.Name) ist gültig" -ForegroundColor Green
    } else {
        Write-Host "❌ FEHLER ($($selected.Algo)): $($_.Name) ist beschädigt oder falsch!" -ForegroundColor Red
        Write-Host "   Erwartet:   $expectedHash"
        Write-Host "   Tatsächlich: $actualHash"
    }
}
