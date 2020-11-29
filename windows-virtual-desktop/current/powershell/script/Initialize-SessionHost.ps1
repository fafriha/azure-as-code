<#
.SYNOPSIS
Deploys Chocolatey, Windows Virtual Desktop agents and FSLogix agent.

.DESCRIPTION
This script will get Chocolatey, Windows Virtual Desktop, and FSLogix agents from Chocolatey and install them.
A host pool registration token is required when installing the Windows Virtual Desktop infrastructure agent.

.PARAMETER AddSessionhostToHostpool
Switch to enable adding this session host to the hostpool

.PARAMETER MoveUserProfiles
Switch to enable the redirection of user profiles to the file share

.EXAMPLE
.\Initialize-SessionHost.ps1 -AddSessionhostToHostpool <registrationtoken> -MoveUserProfiles <azurefileshareuri>
#>

Param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$AddSessionHostToHostpool,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$MoveUserProfiles
)

############################################################## Funtions ########################################################

function Add-SessionhostToHostpool ([string]$RegistrationToken)
{
    $null = choco install wvd-agent --params "/REGISTRATIONTOKEN:$RegistrationToken" --ignore-checksums -y --stoponfirstfailure
    $null = choco install wvd-boot-loader --ignore-checksums -y --stoponfirstfailure
    return $LASTEXITCODE
}

function Move-UserProfiles ([string]$FileShareUri)
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

################################################################# Main #################################################################
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
        $rtExitCode = Add-SessionHostToHostpool $AddSessionHostToHostpool

        if($rtExitCode -ne 0)
        {
            throw "Could not register session host to hostpool. Function returned exit code $rtExitCode."
        }
        else 
        {
            Write-Output "Done."
        }
    }  
        
    if($MoveUserProfiles)
    {
        ## Calling function
        Write-Output "Installing FSLogix agent and configuring remote profiles..."
        $oupExitCode = Move-UserProfiles $MoveUserProfiles

        if($oupExitCode -ne 0)
        {
            throw "Could not redirect user profiles to the remote storage. Function returned exit code $oupExitCode."
        }
        else 
        {
            Write-Output "Done."
        }
    }
}
Catch
{
    Write-Error $_.Exception.Message
    exit 1
}
Finally
{
    Write-Host "Restarting..."
    Restart-Computer -Force
    exit $LASTEXITCODE
}