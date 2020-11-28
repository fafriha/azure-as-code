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

.PARAMETER MoveUserProfiles
Switch to enable the redirection of user profiles to the file share

.EXAMPLE
.\Initialize-SessionHost.ps1 -AddSessionhostToHostpool <registrationtoken> -AddAzureFileShareToDomain <azurefileshareuri> -OrganizationalUnit <oudistinguishedname> -MoveUserProfiles <azurefileshareuri> -AddPowerShellCore
#>

Param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$AddSessionHostToHostpool,

    [Parameter(ParameterSetName = "JoinStorageAccount", Mandatory = $true)]
    [ValidateNotNullOrEmpty()][string]$AddAzureFileShareToDomain,

    [Parameter(ParameterSetName = "JoinStorageAccount", Mandatory = $false)]
    [ValidateNotNullOrEmpty()][string]$OrganizationalUnit,

    [Parameter(ParameterSetName = "JoinStorageAccount", Mandatory = $true)]
    [ValidateNotNullOrEmpty()][string]$JoinDomainAccountName,

    [Parameter(ParameterSetName = "JoinStorageAccount", Mandatory = $true)]
    [ValidateNotNullOrEmpty()][string]$KeyVaultName,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$MoveUserProfiles,

    [Parameter(Mandatory = $false)]
    [switch]$AddPowerShellCore
)

############################################################## Funtions ########################################################
function Start-CommandAsDifferentUser ([System.Management.Automation.PSCredential]$Credential, [string]$Cmdlet)
{  
    # Defining parameters
    $outputFile = "$env:temp\Start-CommandAsDifferentUser.log"

    # Starting the process
    (Start-Process -FilePath "powershell.exe" -Credential $Credential -ArgumentList $Cmdlet -NoNewWindow -PassThru -RedirectStandardOutput $outputFile).WaitForExit()
    
    # Reading the output
    If (Test-Path $outputFile)
    {
        if((Get-Content $outputFile) -contains "Error")
        {
            $output = 1
        }
        else 
        {
            $output = 0    
        }
        
        Remove-Item $outputFile
    }
    else
    {
        $output = 1
    }

    return $output
}

function Add-SessionhostToHostpool ([string]$RegistrationToken)
{
    $null = choco install wvd-agent --params "/REGISTRATIONTOKEN:$RegistrationToken" --ignore-checksums -y --stoponfirstfailure
    $null = choco install wvd-boot-loader --ignore-checksums -y --stoponfirstfailure
    return $LASTEXITCODE
}

function Add-AzureFileShareToDomain (
    $FileShareUri,
    [string]$JoinDomainAccountName,
    [string]$KeyVaultName,
    [Parameter(Mandatory = $false)]$OrganizationalUnit
    )
{
    try 
    {
        # Checking storage account

        # Defining parameters
        $path = "$env:TEMP\AzFilesHybrid"
        $psModPath = $env:PSModulePath.Split(";")[0]
        $storageAccountName = $FileShareUri.Split(".")[1]
        $subscriptionId = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance/compute/subscriptionId?api-version=2020-10-01&format=text"
        $resourceGroupName = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance/compute/resourceGroupName?api-version=2020-10-01&format=text"
        $token = (Invoke-RestMethod -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2020-01-01&resource=https%3A%2F%2Fvault.azure.net' -Method GET -Headers @{Metadata="true"}).access_token
        $password = (Invoke-RestMethod -Uri "https://$KeyVaultName.azure.net/secrets/$JoinDomainAccountName?api-version=2020-01-01" -Method GET -Headers @{Authorization="Bearer $token"}).value | ConvertTo-SecureString -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $JoinDomainAccountName, $password
        $uri = "https://github.com/Azure-Samples/azure-files-samples/releases/download/" + ((Invoke-WebRequest 'https://github.com/Azure-Samples/azure-files-samples/releases/latest' -Headers @{"Accept"="application/json"}).Content | ConvertFrom-Json).tag_name + "/AzFilesHybrid.zip"

        if (!(Test-Path -Path $psModPath)) 
        {
            New-Item -Path $psModPath -ItemType Directory | Out-Null
        }

        # Downloading latest module
        Invoke-WebRequest -Uri $uri -OutFile "$path.zip" | Unblock-File

        # Extracting archive
        Expand-Archive -LiteralPath "$path.zip" -DestinationPath $path -Force

        # Importing data file
        $psdFile = Import-PowerShellDataFile -Path "$path\AzFilesHybrid.psd1"

        # Creating module path
        $desiredModulePath = "$psModPath\AzFilesHybrid\$($psdFile.ModuleVersion)\"
        if (!(Test-Path -Path $desiredModulePath)) 
        {
            New-Item -Path $desiredModulePath -ItemType Directory | Out-Null
        }

        Copy-Item -Path "$path\AzFilesHybrid.psd1" -Destination $desiredModulePath
        Copy-Item -Path "$path\AzFilesHybrid.psm1" -Destination $desiredModulePath

        # Removing archive
        Remove-Item -Path "$path.zip" -Recurse -Force   

        # Importing AzFilesHybrid module
        Install-Module PowerShellGet, Az -Force -Scope AllUsers
        Import-Module -Name AzFilesHybrid -Global 

        # Registering the target storage account with active directory 
        if($OrganizationalUnit)
        {
            $cmdlet = Join-AzStorageAccountForAuth -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName -DomainAccountType "ComputerAccount" -OrganizationalUnitDistinguishedName $OrganizationalUnit -EncryptionType "AES256,RC4"
        }
        else 
        {
            $cmdlet = Join-AzStorageAccountForAuth -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName -DomainAccountType "ComputerAccount" -EncryptionType "AES256,RC4"
        }

        # Running as join domain account
        $command = "Connect-AzAccount -Identity -Subscription $subscriptionId; $cmdlet"
        #Start-CommandAsDifferentUser($cred, $command)

        Write-Output "Done."
    }
    catch 
    {
        Write-Error $_.Exception
        exit $LASTEXITCODE
    }
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

function Add-PowerShellCore ()
{
    ## Should be installed on image creation
    $null = choco install powershell-core --stoponfirstfailure -y
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
        $rtExitCode = Add-SessionHostToHostpool($AddSessionHostToHostpool)

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
        $oupExitCode = Move-UserProfiles($MoveUserProfiles)

        if($oupExitCode -ne 0)
        {
            throw "Could not redirect user profiles to the remote storage. Function returned exit code $oupExitCode."
        }
        else 
        {
            Write-Output "Done."
        }
    }

    if($AddAzureFileShareToDomain)
    {
        ## Calling function
        Write-Output "Adding Azure File Share to the current domain..."
        $aaftdExitCode = Add-AzureFileShareToDomain($AddAzureFileShareToDomain, $JoinDomainAccountName, $KeyVaultName, $OrganizationalUnit)

        if($aaftdExitCode -ne 0)
        {
            throw "Could not add the file share to the domain. Function returned exit code $aaftdExitCode."
        }
        else 
        {
            Write-Output "Done."
        }
    }

    if($AddPowerShellCore)
    {
        ## Calling function
        Write-Output "Installing latest PowerShell version..."
        $apscExitcode = Add-PowerShellCore

        if($apscExitcode -ne 0)
        {
            throw "Could not install the latest PowerShell Code version. Function returned exit code $apscExitcode."
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