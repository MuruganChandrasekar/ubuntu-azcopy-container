# Input bindings are passed in via param block.
param($Timer)

# Load the shared code to start the container
. .\Shared\Start-AzCopy-Container.ps1

$date = Get-Date

# Initiate the AzCopy
Start-AzCopy-Container `
    -ContainerName $Env:StaticContentBackup_ContainerName `
    -LogStorageAccount $Env:StaticContentBackup_LogStorageAccount `
    -SourceAccount $Env:StaticContentBackup_SourceAccount `
    -SourceToken $Env:StaticContentBackup_SourceToken `
    -DestinationAccount $Env:StaticContentBackup_DestinationAccount `
    -DestinationToken $Env:StaticContentBackup_DestinationToken `
    -DestinationContainer $date.Year `
    -DestinationPath ($date.Month.ToString('00') + '/')

# Wait for it to finish
do {
    $ContainerStatus = (Get-AzContainerGroup -ResourceGroupName $Env:WEBSITE_RESOURCE_GROUP -Name $Env:StaticContentBackup_ContainerName).State
    Write-Host "Container Status: $ContainerStatus"
    Start-Sleep -Seconds 300
} while ($ContainerStatus -eq 'Running')

# Calculate the rough elapsed time
$elapsed = $(New-TimeSpan $date $(Get-Date)).ToString('hh\:mm\:ss')

# Fetch logs
$logs = Get-AzContainerInstanceLog -ResourceGroupName $Env:WEBSITE_RESOURCE_GROUP -ContainerGroupName $Env:StaticContentBackup_ContainerName

# Truncate logs to just the summary, if it exists
$logIndex = $logs.IndexOf('Job ')
if ($logIndex -ne -1) { $logs = $logs.Substring($logIndex) }

# Send update to Slack
switch ($ContainerStatus) {
    "Succeeded" { $color = "good" }
    "Failed" { $color = "danger" }
    Default { $color = "warning" }
}

$Body = @"
    {
        "username": "Static Content Backup",
        "text": "Backup Container *$Env:StaticContentBackup_ContainerName* completed.",
        "icon_emoji":":lion_face:",
        "attachments": [
            {
                "fallback": "Status: $ContainerStatus, Elapsed: ",
                "color": "$color",                
                "fields": [
                    {
                        "title": "Status",
                        "value": "$ContainerStatus",
                        "short": true
                    },
                    {
                        "title": "Elapsed Time",
                        "value": "$elapsed",
                        "short": true
                    },
                    {
                        "title": "Console Logs",
                        "value": "$logs",
                        "short": false
                    }
                ]
            }
        ]
    }
"@

# Post to Slack
Invoke-RestMethod -uri $Env:StaticContentBackup_SlackChannelUrl -Method Post -body $Body -ContentType 'application/json'