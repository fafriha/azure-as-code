<#
.SYNOPSIS
Deploys Windows Virtual Desktop agents

.DESCRIPTION
This script will get the Windows Virtual Desktop bootloader and infrastructure agents from Chocolatey and install them.
A host pool registration token is required when installing the Windows Virtual Desktop infrastructure agent.

.PARAMETER RegistrationToken
Required the host pool registration token

.EXAMPLE
.\Install-WVDAgents.ps1 -RegistrationToken $registrationToken
#>

Param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RegistrationToken
)

try 
{
    Write-Output "Enabling TLS 1.2."
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    Write-Output "Installing Chocolatey."
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    Write-Output "Installing Windows Virtual Desktop agent boot loader"
    #choco install wvd-boot-loader --pre -y

    Write-Output "Installing Windows Virtual Desktop agent"
    choco install wvd-agent --params '/REGISTRATIONTOKEN:$registrationToken' -y
}
catch
{
    Write-Error $_.Exception
    throw $_.Exception
}
finally
{
    Write-Host "End of execution."
    $LASTEXITCODE
}