<#
.SYNOPSIS
Deploys latest PowerShell version, Chocolatey, Windows Virtual Desktop agents and FSLogix agent.

.DESCRIPTION
This script will get the latest PowerShell version, Chocolatey, Windows Virtual Desktop bootloader and infrastructure agents and FSLogix agents rom Chocolatey and install them.
A host pool registration token is required when installing the Windows Virtual Desktop infrastructure agent.

.PARAMETER RegistrationToken
Requires the host pool registration token

.PARAMETER FileShareUri
Requires the storage account file share uri to store user profile

.PARAMETER LocalAdminName
Requires the local administrator account name to exclude its user profile redirection to the storage account

.EXAMPLE
.\Install-Agents.ps1 -RegistrationToken <token> -FileShare <uncpathofazurefileshare> -LocalAdminName <nameoflocaladminaccount> 
#>

Param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RegistrationToken,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$FileShareUri,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$LocalAdminName
)

Try 
{
    # Defining settings
    $path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
    $settings = @{
        VHDLocations = $FileShareUri.Replace('/','\').Replace('https:','')
        Enabled = 1
        FlipFlopProfileDirectoryName = 1
        DeleteLocalProfileWhenVHDShouldApply = 1
        PreventLoginWithFailure = 1
        PreventLoginWithTempProfile = 1
    }

    Write-Output "Enabling TLS 1.2..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    ## Should be installed on image creation
    Write-Output "Installing latest PowerShell version..."
    Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet -AddToPath"

    ## Should be installed on image creation
    Write-Output "Installing Chocolatey..."
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    
    Write-Output "Installing Windows Virtual Desktop agent..."
    choco install wvd-agent --params "/REGISTRATIONTOKEN:$registrationToken" --ignore-checksums -y

    Write-Output "Installing Windows Virtual Desktop boot loader agent..."
    choco install wvd-boot-loader --ignore-checksums -y
    
    ## Should be installed on image creation
    Write-Output "Installing FSLogix agent..."
    choco install fslogix --ignore-checksums -y

    ## Should be configured via GPOs
    Write-Output "Configuring remote profiles..."
    Add-LocalGroupMember -Group "FSLogix Profile Exclude List" -Member $LocalAdminName
    New-Item $path -Force

    foreach ($setting in $settings.GetEnumerator())
    {
        if ($setting.Name -eq 'VHDLocations')
        {
            New-ItemProperty -Path $path -Name $setting.Name -Value $setting.Value -PropertyType MultiString -Force
        }
        else 
        {
            New-ItemProperty -Path $path -Name $setting.Name -Value $setting.Value -PropertyType DWord -Force
        }
    }
}
Catch
{
    Write-Error $_.Exception
    throw $_.Exception
}
Finally
{
    Write-Host "Restarting..."
    Restart-Computer -Force
    $LASTEXITCODE
}