<#
.SYNOPSIS
Deploys latest PowerShell version, Chocolatey, Windows Virtual Desktop agents and FSLogix agent.

.DESCRIPTION
This script will get the latest PowerShell version, Chocolatey, Windows Virtual Desktop bootloader and infrastructure agents and FSLogix agents rom Chocolatey and install them.
A host pool registration token is required when installing the Windows Virtual Desktop infrastructure agent.

.PARAMETER RegistrationToken
The registration token of the hostpool in which the session host will be added

.PARAMETER FileShareUri
The Uri of the file share which will be used to store all user profiles

.PARAMETER AddPowerShellCore
Swtich to enable the installation of the latest Powershell Core version

.PARAMETER AddSessionhostToHostpool
Switch to enable adding this session host to the hostpool

.PARAMETER AddAzureFileShareToDomain
Switch to enable adding the file share to the domain

.PARAMETER RedirectProfilesToAzureFileShare
Switch to enable the redirection of user profiles to the file share

.EXAMPLE
.\Initialize-SessionHost.ps1 -AddSessionhostToHostpool <registrationtoken> -AddAzureFileShareToDomain <azurefileshareuri> -OffloadUserProfiles <azurefileshareuri> -AddPowerShellCore
#>

Param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$AddSessionHostToHostpool,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$AddAzureFileShareToDomain,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$OffloadUserProfiles,

    [Parameter(Mandatory = $false)]
    [switch]$AddPowerShellCore
)

function AddSessionhostToHostpool ([string]$RegistrationToken)
{
    $null = choco install wvd-agent --params "/REGISTRATIONTOKEN:$RegistrationToken" --ignore-checksums -y --stoponfirstfailure
    $null = choco install wvd-boot-loader --ignore-checksums -y --stoponfirstfailure
    return $LASTEXITCODE
}

function AddAzureFileShareToDomain ([string]$Path)
{
    ######################################## Adding storage account to the domain
    # Download latest module
    # Get join domain account from parameter or Key Vault
    # Join storage account to domain
    ##############################################################################
    
    return $LASTEXITCODE
}

function OffloadUserProfiles ([string]$Path)
{
    ## Defining settings
    $localAdministrators = (Get-LocalGroupMember -Group "Administrators").Name
    $path = 'HKLM:\SOFTWARE\FSLogix\Profiles'
    $settings = @{
        VHDLocations = $FileShareUri.Replace('/','\').Replace('https:','')
        Enabled = 1
        FlipFlopProfileDirectoryName = 1
        DeleteLocalProfileWhenVHDShouldApply = 1
        PreventLoginWithFailure = 1
        PreventLoginWithTempProfile = 1
    }

    ## Should be installed on image creation
    $null = choco install fslogix --ignore-checksums -y --stoponfirstfailure 

    ## Should be configured via GPOs
    $null = New-Item $path -Force -ErrorAction Stop

    foreach ($localAdministrator in $localAdministrators)
    {
        Add-LocalGroupMember -Group "FSLogix Profile Exclude List" -Member $localAdministrator
    }
    
    foreach ($setting in $settings.GetEnumerator())
    {
        if ($setting.Name -eq 'VHDLocations')
        {
            $null = New-ItemProperty -Path $path -Name $setting.Name -Value $setting.Value -PropertyType MultiString -Force
        }
        else 
        {
            $null = New-ItemProperty -Path $path -Name $setting.Name -Value $setting.Value -PropertyType DWord -Force
        }
    }

    return $LASTEXITCODE
}

function AddPowerShellCore ()
{
    ## Should be installed on image creation
    $null = choco install powershell-core --stoponfirstfailure
    return $LASTEXITCODE 
}

Try 
{
    ## Should be installed on image creation
    Write-Output "Enabling TLS 1.2 and installing Chocolatey..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -ErrorAction Stop

    if($AddSessionHostToHostpool)
    {
        ## Calling function
        Write-Output "Installing Windows Virtual Desktop agents..."
        $rtExitCode = AddSessionHostToHostpool($AddSessionHostToHostpool)

        if($rtExitCode -ne 0)
        {
            throw "Could not register session host to hostpool. Function returned exit code $rtExitCode."
        }
    }  
        
    if($OffloadUserProfiles)
    {
        ## Calling function
        Write-Output "Installing FSLogix agent and configuring remote profiles..."
        $oupExitCode = OffloadUserProfiles($OffloadUserProfiles)

        if($oupExitCode -ne 0)
        {
            throw "Could not redirect user profiles to the remote storage. Function returned exit code $oupExitCode."
        }
    }

    if($AddAzureFileShareToDomain)
    {
        ## Calling function
        Write-Output "Adding Azure File Share to the current domain..."
        $aaftdExitCode = AddAzureFileShareToDomain($AddAzureFileShareToDomain)

        if($aaftdExitCode -ne 0)
        {
            throw "Could not add the file share to the domain. Function returned exit code $aaftdExitCode."
        }
    }

    if($AddPowerShellCore)
    {
        ## Calling function
        Write-Output "Installing latest PowerShell version..."
        $apscExitcode = AddPowerShellCore

        if($apscExitcode -ne 0)
        {
            throw "Could not install the latest PowerShell Code version. Function returned exit code $apscExitcode."
        }
    }
}
Catch
{
    Write-Error $_.Exception.Message
    exit $LASTEXITCODE
}
Finally
{
    Write-Host "Restarting..."
    Restart-Computer -Force
    exit $LASTEXITCODE
}