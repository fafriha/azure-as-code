param($eventGridEvent, $TriggerMetadata)

## Getting host pool registration token
Write-Host "Received event."

try
{
    $keyVaultName = $eventGridEvent.data.'VaultName'
    $hostPoolName = $eventGridEvent.subject
    $resourceGroupName = (($eventGridEvent.topic) -split "/")[4]

    Write-Host "Generating registration token for host pool $hostPoolName."
    
    $registrationToken = (New-AzWvdRegistrationInfo -ResourceGroupName $resourceGroupName -HostPoolName $hostPoolName -ExpirationTime $((get-date).ToUniversalTime().AddDays(7).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))).Token

    $Secret = ConvertTo-SecureString -String $registrationToken -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $hostPoolName -SecretValue $Secret -Expires $((get-date).ToUniversalTime().AddDays(7).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))

    Write-Host "A registration token for $hostPoolName has been created successfully."
}
catch
{
    Write-Error $_.Exception
    throw $_.Exception
}

Write-Host "End of execution."
## End of getting host pool registration token