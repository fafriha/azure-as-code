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
    [string]$RegistrationToken,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$LocalAdminName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$FileShare
)

try 
{
    # Defining settings
    $path = "HKLM:\SOFTWARE\FSLogix\Profiles"
    $settings = @{
        VHDLocations = $FileShare
        Enabled = 1
        FlipFlopProfileDirectoryName = 1
        DeleteLocalProfileWhenVHDShouldApply = 1
        PreventLoginWithFailure = 1
        PreventLoginWithTempProfile = 1
    }

    Write-Output "Enabling TLS 1.2."
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    Write-Output "Installing Chocolatey..."
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    
    Write-Output "Installing Windows Virtual Desktop agent..."
    choco install wvd-agent --params "/REGISTRATIONTOKEN:$registrationToken" --ignore-checksums -y

    Write-Output "Installing Windows Virtual Desktop boot loader agent..."
    choco install wvd-boot-loader --ignore-checksums -y
    
    Write-Output "Installing FSLogix agent..."
    choco install fslogix -y

    Write-Output "Configuring remote profiles..."
    Add-LocalGroupMember -Group "FSLogix Profile Exclude List" -Member $LocalAdminName
    New-Item –Path $path –Force
    
    foreach ($setting in $settings.GetEnumerator())
    {
        if ($setting.Name -eq 'VHDLocations') 
        {
            New-ItemProperty -Path $path -Name $setting.Name -Value $setting.Value -PropertyType MULTI_SZ -Force     
        }
        else 
        {
            New-ItemProperty -Path $path -Name $setting.Name -Value $setting.Value -PropertyType DWORD -Force
        }
    }
}
catch
{
    Write-Error $_.Exception
    throw $_.Exception
}
finally
{
    Write-Host "Restarting..."
    Restart-Computer -Force
    $LASTEXITCODE
}