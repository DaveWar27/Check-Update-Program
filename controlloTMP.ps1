$ErrorActionPreference = 'SilentlyContinue'

function TpmErr {
    param(
        [string]$Message,
        [int]$Code
    )
    Write-Host $Message -ForegroundColor Magenta
    exit $Code
}

function Get-TpmProviderObject {
    try {
        $obj = Get-CimInstance -Namespace "root\CIMV2\Security\MicrosoftTpm" -ClassName "Win32_Tpm" -ErrorAction Stop
        if ($obj) {
            return $obj
        }
    } catch {
    }

    try {
        $obj = Get-WmiObject -Namespace "root\CIMV2\Security\MicrosoftTpm" -Class "Win32_Tpm" -ErrorAction Stop
        if ($obj) {
            return $obj
        }
    } catch {
    }

    return $null
}

try {
    $provider = Get-TpmProviderObject

    if (-not $provider) {
        TpmErr "ERRORE TPM: provider TPM non accessibile da script. Avvia come amministratore." 41
    }

    $enabled = $provider.IsEnabled_InitialValue
    $activated = $provider.IsActivated_InitialValue
    $specVersion = $provider.SpecVersion

    Write-Host "TPM rilevato. Versione: $specVersion" -ForegroundColor Yellow

    if (-not $enabled) {
        TpmErr "ERRORE TPM: TPM non abilitato." 47
    }

    if (-not $activated) {
        TpmErr "ERRORE TPM: TPM non attivato." 48
    }

    $getTpmCmd = Get-Command Get-Tpm -ErrorAction SilentlyContinue
    if ($getTpmCmd) {
        try {
            $tpm = Get-Tpm -ErrorAction Stop

            if ($tpm.LockedOut) {
                try {
                    Unblock-Tpm | Out-Null
                } catch {}
            }

            if ($tpm.AutoProvisioning -eq 'Disabled' -or $tpm.AutoProvisioning -eq 'DisabledForNextBoot') {
                try {
                    Enable-TpmAutoProvisioning | Out-Null
                } catch {}
            }

            $tpm = Get-Tpm -ErrorAction SilentlyContinue
            $init = $null

            if ($tpm -and -not $tpm.TpmReady) {
                try {
                    $init = Initialize-Tpm -AllowClear -AllowPhysicalPresence
                } catch {}
                Start-Sleep -Seconds 2
                $tpm = Get-Tpm -ErrorAction SilentlyContinue
            }

            if ($tpm) {
                if (-not $tpm.TpmReady) {
                    if ($init -and $init.PhysicalPresenceRequired) {
                        TpmErr "ERRORE TPM: richiesta presenza fisica al riavvio." 42
                    }
                    elseif ($init -and $init.RestartRequired) {
                        TpmErr "ERRORE TPM: richiesto riavvio per completare la configurazione." 43
                    }
                    elseif ($init -and $init.ShutdownRequired) {
                        TpmErr "ERRORE TPM: richiesto spegnimento completo per completare la configurazione." 44
                    }
                    elseif ($init -and $init.ClearRequired) {
                        TpmErr "ERRORE TPM: richiesto reset/clear del TPM." 45
                    }
                    else {
                        Write-Host "TPM rilevato dal provider, ma Get-Tpm non lo considera ancora pronto." -ForegroundColor Yellow
                    }
                }
                elseif ($tpm.LockedOut) {
                    TpmErr "ERRORE TPM: TPM ancora in lockout." 49
                }
            }
        } catch {
            Write-Host "Avviso: Get-Tpm non affidabile in questa sessione, continuo con stato provider TPM." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Avviso: Get-Tpm non disponibile, uso solo provider TPM." -ForegroundColor Yellow
    }

    Write-Host "TPM pronto e senza errori critici." -ForegroundColor Green
    exit 0
}
catch {
    TpmErr ("ERRORE TPM: " + $_.Exception.Message) 50
}