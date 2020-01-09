function Start-AzCopy-Container(
    [string]$ContainerName,
    [string]$LogStorageAccount,
    [string]$SourceAccount,
    [string]$SourceToken,
    [string]$DestinationAccount,
    [string]$DestinationToken,
    [string]$DestinationContainer='',
    [string]$DestinationPath=''
) {
    $currentUTCtime = (Get-Date).ToFileTimeUtc()
    
    # Combine the destinations, make sure the destination container exists
    $DestinationSeparator = ''
    if (($DestinationContainer -ne '') -and ($DestinationPath -ne '')) {
        $DestinationSeparator = '/'
    }

    if ($DestinationContainer -ne '') {
        Write-Host "Ensuring container [$DestinationContainer] exists in [$DestinationAccount]"
        $context = New-AzStorageContext -StorageAccountName $DestinationAccount -SasToken $DestinationToken
        $existingContainer = Get-AzStorageContainer -Name $DestinationContainer -Context $context
        if (!$existingContainer) {
            New-AzStorageContainer -Name $DestinationContainer -Permission Off -Context $context
        }
    }

    # Credentials for Storage Account Logs
    $secpwd = ConvertTo-SecureString (Get-AzStorageAccountKey -ResourceGroupName $Env:WEBSITE_RESOURCE_GROUP -Name $LogStorageAccount).Value[0] -AsPlainText -Force
    $logCreds = New-Object System.Management.Automation.PSCredential ($LogStorageAccount, $secpwd)

    Write-Host "Starting container [$ContainerName] to copy from [$SourceAccount/*] to [$DestinationAccount/$DestinationContainer$DestinationSeparator$DestinationPath]..."

    # Environment variables
    $envVars = @{
        "AZCOPY_CONCURRENCY_VALUE" = ""
        "AZCOPY_CONCURRENT_FILES" = 128
        "AZCOPY_JOB_PLAN_LOCATION" = "/mnt/logs/$currentUTCtime/plans"
        "AZCOPY_LOG_LOCATION" = "/mnt/logs/$currentUTCtime"
        "CURRENT_DATE" = "$currentUTCtime"
        "SOURCE"       = "https://$SourceAccount.blob.core.windows.net/$SourceToken"
        "DESTINATION"  = "https://$DestinationAccount.blob.core.windows.net/$DestinationContainer$DestinationSeparator$DestinationPath$DestinationToken"
    }

    # Create/Update the Container
    New-AzContainerGroup `
        -ResourceGroupName $Env:WEBSITE_RESOURCE_GROUP `
        -Name $ContainerName `
        -Image "srikantsarwa/ubuntu-azcopy" `
        -OsType Linux `
        -Cpu 4 `
        -MemoryInGB 8 `
        -AzureFileVolumeShareName "staticbackuplogs" `
        -AzureFileVolumeAccountCredential $logCreds `
        -AzureFileVolumeMountPath "/mnt/logs" `
        -EnvironmentVariable $envVars `
        -RestartPolicy Never `
        -Command '/bin/bash -c "azcopy copy $SOURCE $DESTINATION --overwrite false --recursive=true --log-level ERROR --check-length=false"'

    Write-Host "Container started."
}