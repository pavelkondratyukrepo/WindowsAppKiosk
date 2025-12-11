param(
    [int]$IdleWaitTimeoutSeconds = 5
)

$EventLog = 'Windows-App-Kiosk'
$EventSource = 'AutoLogoff'

# Ensure event source exists (requires admin to create initially, but script runs as user)
# The main configuration script should have created this source.
try {
    Write-EventLog -LogName $EventLog -Source $EventSource -EventId 1000 -EntryType Information -Message "Idle limit reached. Waiting $IdleWaitTimeoutSeconds seconds before logoff."
}
catch {
    # Fallback if logging fails
}

Start-Sleep -Seconds $IdleWaitTimeoutSeconds

try {
    Write-EventLog -LogName $EventLog -Source $EventSource -EventId 1001 -EntryType Information -Message "Logoff initiated due to inactivity."
}
catch {
    # Fallback
}

& logoff.exe