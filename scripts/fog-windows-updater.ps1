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
    Write-Log "Starte Windows Update Suche..."
    Add-WUServiceManager -MicrosoftUpdate -Confirm:$false
    $updates = Get-WindowsUpdate -MicrosoftUpdate -IgnoreReboot -ErrorAction Stop
    if (-not $updates -or $updates.Count -eq 0) {
        Write-Log "Keine Updates gefunden. System ist aktuell."
    } else {
        Write-Log "Es wurden $($updates.Count) Updates gefunden:"
        foreach ($update in $updates) {
            Write-Log " - $($update.Title) (KB: $($update.KBArticleIDs -join ', '))"
        }
        Write-Log "Starte Installation aller Updates..."
        try {
            $kbList = $updates | Where-Object { $_.KBArticleIDs } | ForEach-Object { $_.KBArticleIDs } | Select-Object -Unique
            Install-WindowsUpdate -MicrosoftUpdate -KBArticleID $kbList -AcceptAll -IgnoreReboot -ErrorAction Stop -Verbose
            Write-Log "Alle Updates wurden erfolgreich installiert. Das system muss ggf. neugestartet werden."
        } catch {
            Write-Log "Fehler bei der Installation: $($_.Exception.Message)" "ERROR"
        }
    }
} catch {
    Write-Log "Fehler mit Windows Update: $($_.Exception.Message)" "ERROR"
}
Write-Log "=== Script beendet ==="
pause
exit
