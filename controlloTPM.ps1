$ErrorActionPreference = 'Stop'
try {
    $fail = @()
    $t = $null
    try { $t = Get-Tpm } catch { $fail += 'Get-Tpm non disponibile' }
    if ($t) {
        Write-Host ('TPM presente: ' + $t.TpmPresent) -ForegroundColor Gray
        Write-Host ('TPM pronto: ' + $t.TpmReady) -ForegroundColor Gray
        if (-not $t.TpmPresent) { $fail += 'TPM non presente' }
        if (-not $t.TpmReady) { $fail += 'TPM non pronto' }
    }
    try {
        $secureBoot = Confirm-SecureBootUEFI
        if ($secureBoot -eq $false) { $fail += 'Secure Boot disattivo' }
    } catch {
        $fail += 'Secure Boot non verificabile'
    }
    try {
        $reg = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name PEFirmwareType -ErrorAction Stop
        if ($reg.PEFirmwareType -eq 1) { $fail += 'Sistema in Legacy BIOS' }
    } catch {
        $fail += 'Firmware non rilevato'
    }
    if ($fail.Count -gt 0) {
        Write-Host 'Problemi TPM/UEFI:' -ForegroundColor Yellow
        $fail | ForEach-Object { Write-Host (' - ' + $_) -ForegroundColor Yellow }
        exit 106
    }
    Write-Host 'TPM / Secure Boot / UEFI: OK' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ('ERRORE TPM: ' + $_.Exception.Message) -ForegroundColor Red
    exit 108
}
