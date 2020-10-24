using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

## Getting host pool's registration token
Write-Output "Getting host pool's registration token."

try
{
    if ($Request.Method -eq "GET")
    {
        if($Request.Query.HostPoolName)
        {
            $hostPoolName = $Request.Query.HostPoolName
            $resourceGroupName = (Get-AzResourceGroup).ResourceGroupName
            $keyVaultName = (Get-AzKeyVault -ResourceGroupName $resourceGroupName).VaultName
            
            $registrationToken = (Get-AzWvdRegistrationInfo -ResourceGroupName $resourceGroupName -HostPoolName $hostPoolName).Token

            if (!$registrationToken)
            {
                $registrationToken = (New-AzWvdRegistrationInfo -ResourceGroupName $resourceGroupName -HostPoolName $hostPoolName -ExpirationTime $((get-date).ToUniversalTime().AddDays(7).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))).Token
            }
        
            $Secret = ConvertTo-SecureString -String $registrationToken -AsPlainText -Force
            Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $hostPoolName -SecretValue $Secret -Expires $((get-date).ToUniversalTime().AddDays(7).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))

            $status = 200
            $body = "A registration token for $hostPoolName has been created successfully."
        }
        else
        {
            $status = 400
            $body = "A parameter is missing."
        }
    }
    else
    {
        $status = 405
        $body = "Only GET method is allowed."

        Write-Output "Unauthorized method."
    }
}
catch
{
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = 500
    })

    Write-Error $_.Exception
    throw $_.Exception
}

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
})

Write-Output "End of execution."
## End of getting host pool's registration token