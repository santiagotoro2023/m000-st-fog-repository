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
    Write-Log "Verifizieren, ob Git installiert ist..."
    $gitPath = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($gitPath) {
        Write-Log "Git gefunden. Versuche Git zu deinstallieren..."
        $gitMSI = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "Git*" }
        if ($gitMSI) {
            foreach ($git in $gitMSI) {
                Write-Log "Deinstalliere: $($git.Name)..."
                $git.Uninstall() | Out-Null
                Write-Log "Git erfolgreich deinstalliert."
            }
        } else {
            $gitUninstall = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall" |
                Get-ItemProperty |
                Where-Object { $_.DisplayName -like "Git*" }
            if ($gitUninstall) {
                foreach ($entry in $gitUninstall) {
                    Write-Log "Starte Deinstallation von $($entry.DisplayName)..."
                    Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $($entry.PSChildName) /quiet /norestart" -Wait
                    Write-Log "Git erfolgreich deinstalliert."
                }
            } else {
                Write-Log "Git Deinstallationsinformationen nicht gefunden." "WARN"
            }
        }
    } else {
        Write-Log "Git ist nicht installiert."
    }
} catch {
    Write-Log "Fehler bei der Deinstallation von Git: $($_.Exception.Message)" "ERROR"
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
    Write-Log "Starte Windows Update Suche..."
    Add-WUServiceManager -MicrosoftUpdate -Confirm:$false
    $updatesFound = $true
    $loopCount = 0
    while ($updatesFound) {
        $loopCount++
        Write-Log "Update-Durchlauf #$loopCount wird gestartet..."
        $updates = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot -ErrorAction Stop
        if (-not $updates -or $updates.Count -eq 0) {
            Write-Log "Keine weiteren Updates gefunden. System ist aktuell."
            $updatesFound = $false
            break
        }
        Write-Log "Es wurden $($updates.Count) Updates gefunden:"
        foreach ($update in $updates) {
            Write-Log " - $($update.Title) (KB: $($update.KBArticleIDs -join ', '))"
        }
        try {
            Write-Log "Starte Installation aller Updates..."
            Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot -ErrorAction Stop -Verbose
            Write-Log "Alle Updates des Durchlaufs #$loopCount wurden installiert."
        } catch {
            Write-Log ("Fehler bei der Installation im Durchlauf #{0}: {1}" -f $loopCount, $_.Exception.Message) "ERROR"
        }
        Write-Log "Starte Windows Update Dienst neu..."
        Restart-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 15
    }
    Write-Log "Alle Update-Prozesse abgeschlossen. Entferne geplante Aufgabe 'StartUpdateWindows'..."
    $taskName = "StartUpdateWindows"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "Geplante Aufgabe '$taskName' erfolgreich entfernt."
} catch {
    Write-Log ("Fehler im Windows Update Prozess: {0}" -f $_.Exception.Message) "ERROR"
}
Write-Log "=== Script beendet ==="
try {
    Write-Log  "Das System wird in 15 Sekunden automatisch neu gestartet, um die Updates abzuschliessen."
    Start-Sleep -Seconds 15
    Write-Log "Starte Computer neu..."
    Restart-Computer -Force
} catch {
    Write-Log ("Fehler beim Anzeigen der Neustartmeldung oder beim Neustart: {0}" -f $_.Exception.Message) "ERROR"
}
pause
exit

