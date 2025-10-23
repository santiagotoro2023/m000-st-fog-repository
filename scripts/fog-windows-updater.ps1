$logDir = "C:\Users\SIDMAR\FOG"
if (!(Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$logFile = Join-Path $logDir ("UpdateLog_{0}.txt" -f (Get-Date -Format "yyyy-MM-dd_HH-mm-ss"))
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Host $logEntry
}
Write-Log "=== Start des Windows Update Scripts ==="
try {
    Write-Log "Installiere PSWindowsUpdate-Modul..."
    Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
    Write-Log "PSWindowsUpdate-Modul erfolgreich installiert."
} catch {
    Write-Log "Fehler bei der Modulinstallation: $($_.Exception.Message)" "ERROR"
}
try {
    Write-Log "Importiere PSWindowsUpdate-Modul..."
    Import-Module PSWindowsUpdate
    Write-Log "Modul erfolgreich importiert."
} catch {
    Write-Log "Fehler beim Importieren des Moduls: $($_.Exception.Message)" "ERROR"
}
try {
    Write-Log "Suche nach OEM-Key..."
    $oemKey = (Get-CimInstance -ClassName SoftwareLicensingService).OA3xOriginalProductKey
    if ($oemKey) {
        Write-Log "OEM-Key gefunden. Aktiviere Windows..."
        slmgr /ipk $oemKey | Out-Null
        slmgr /ato | Out-Null
        Write-Log "Windows erfolgreich aktiviert."
    } else {
        Write-Log "Kein OEM-Key gefunden." "WARN"
    }
} catch {
    Write-Log "Fehler bei der Windows-Aktivierung: $($_.Exception.Message)" "ERROR"
}
try {
    Write-Log "Entferne geplante Aufgabe 'StartUpdateWindows'..."
    $taskName = "StartUpdateWindows"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "Geplante Aufgabe '$taskName' erfolgreich entfernt."
} catch {
    Write-Log "Fehler beim entfernen der Aufgabe: $($_.Exception.Message)" "ERROR"
}
try {
    Write-Log "Starte Windows Update..."
    Add-WUServiceManager -MicrosoftUpdate -Confirm:$false
    $updates = Get-WindowsUpdate -MicrosoftUpdate -IgnoreReboot -ErrorAction Stop

    if (-not $updates -or $updates.Count -eq 0) {
        Write-Log "Keine Updates gefunden. System ist aktuell."
    } else {
        Write-Log "Es wurden $($updates.Count) Updates gefunden."
        Write-Log "Beginne mit der Installation..."

        foreach ($update in $updates) {
            Write-Log "----------------------------------------------"
            Write-Log "Installiere Update: $($update.Title)"

            try {
                if ($update.KBArticleIDs) {
                    foreach ($kb in $update.KBArticleIDs) {
                        Install-WindowsUpdate -MicrosoftUpdate -KBArticleID $kb -AcceptAll -IgnoreReboot -ErrorAction Stop | Out-Null
                        Write-Log "Erfolgreich installiert: $($update.Title) ($kb)"
                    }
                } else {
                    Write-Log "Update hat keine KB-ID, überspringe Installation." "WARN"
                }
            } catch {
                Write-Log "Fehler beim Installieren von: $($update.Title)" "ERROR"
                Write-Log "   -> $($_.Exception.Message)" "ERROR"
                continue
            }
        }

        Write-Log "Alle Updates wurden verarbeitet. Das System muss ggf. neugestartet werden."
    }
} catch {
    Write-Log "Fehler mit Windows Update: $($_.Exception.Message)" "ERROR"
}
Write-Log "=== Script beendet ==="
pause
exit
