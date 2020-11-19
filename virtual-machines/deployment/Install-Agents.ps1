<#
.SYNOPSIS
Deploys Windows Virtual Desktop agents

.DESCRIPTION
This script will get the Windows Virtual Desktop bootloader and infrastructure agents from Chocolatey and install them.
A host pool registration token is required when installing the Windows Virtual Desktop infrastructure agent.

.PARAMETER RegistrationToken
Required the host pool registration token

.EXAMPLE
.\Install-WVDAgents.ps1 -RegistrationToken <token> -LocalAdminName <nameoflocaladminaccount> -FileShare <uncpathofazurefileshare>
#>

Param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RegistrationToken
)

try 
{
    #Write-Host $FileShare
    Write-Host $RegistrationToken
    #Write-Host $LocalAdminName
}
catch
{
    Write-Error $_.Exception
    throw $_.Exception
}
finally
{
    Write-Host "Restarting..."
    #Restart-Computer -Force
    $LASTEXITCODE
}