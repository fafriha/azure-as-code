<#
.SYNOPSIS
Deploys Chocolatey, Windows Virtual Desktop agents and FSLogix agent.

.DESCRIPTION
This script will get Chocolatey, Windows Virtual Desktop, and FSLogix agents from Chocolatey and install them.
A host pool registration token is required when installing the Windows Virtual Desktop infrastructure agent.

.PARAMETER RegistrationToken
The registration token of the hostpool in which the session host will be added

.PARAMETER FileShareUri
The Uri of the file share which will be used to store all user profiles

.PARAMETER AddSessionhostToHostpool
Switch to enable adding this session host to the hostpool

.PARAMETER AddAzureFileShareToDomain
Switch to enable adding the file share to the domain

.PARAMETER MoveUserProfiles
Switch to enable the redirection of user profiles to the file share

.EXAMPLE
.\Initialize-SessionHost.ps1 -AddSessionhostToHostpool <registrationtoken> -AddAzureFileShareToDomain <azurefileshareuri> -OrganizationalUnit <oudistinguishedname> -MoveUserProfiles <azurefileshareuri>
#>

Param(
    [Parameter(ParameterSetName = "JoinStorageAccount", Mandatory = $true)]
    [ValidateNotNullOrEmpty()][string]$AddAzureFileShareToDomain,

    [Parameter(ParameterSetName = "JoinStorageAccount", Mandatory = $true)]
    [ValidateNotNullOrEmpty()][string]$JoinDomainAccountName,

    [Parameter(ParameterSetName = "JoinStorageAccount", Mandatory = $false)]
    [ValidateNotNullOrEmpty()][string]$OrganizationalUnit,

    [Parameter(ParameterSetName = "JoinStorageAccount", Mandatory = $true)]
    [ValidateNotNullOrEmpty()][string]$KeyVaultName,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$AddSessionHostToHostpool,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$MoveUserProfiles
)

############################################################## Funtions ########################################################
function Start-CommandAsDifferentUser ([PSCredential]$Credential, [string]$Cmdlet)
{  
    # Defining parameters
    $outputFile = "$env:temp\Start-CommandAsDifferentUser.log"

    # Starting the process
    (Start-Process -FilePath "powershell.exe" -Credential $Credential -ArgumentList $Cmdlet -NoNewWindow -PassThru -RedirectStandardOutput $outputFile).WaitForExit()
    
    # Reading the output
    If (Test-Path $outputFile)
    {
        if((Get-Content $outputFile | %{$_ -match "Error"}) -contains $true)
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
    $JoinDomainAccountName,
    $KeyVaultName,
    [Parameter(Mandatory = $false)]$OrganizationalUnit
    )
{
    try 
    {
        # Defining parameters
        $path = "$env:TEMP\AzFilesHybrid"
        $psModPath = $env:PSModulePath.Split(";")[0]
        $storageAccountName = $FileShareUri.Split(".")[1]
        $secretUri = "https://" + $KeyVaultName + ".vault.azure.net/secrets/" + $JoinDomainAccountName + "?api-version=7.1"
        Write-Output "Step 1/8 - Defining parameters. Done."

        $subscriptionId = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance/compute/subscriptionId?api-version=2020-09-01&format=text"
        Write-Output "Step 2/8 - Getting subscription id. Done."

        $resourceGroupName = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance/compute/resourceGroupName?api-version=2020-09-01&format=text"
        Write-Output "Step 3/8 - Getting resource group name. Done."

        $token = (Invoke-RestMethod -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2020-09-01&resource=https%3A%2F%2Fvault.azure.net' -Method GET -Headers @{Metadata="true"}).access_token
        Write-Output "Step 4/8 - Requesting access token. Done."

        $password = (Invoke-RestMethod -Uri $secretUri -Method GET -Headers @{Authorization="Bearer $token"}).value | ConvertTo-SecureString -AsPlainText -Force
        Write-Output "Step 5/8 - Getting secret. Done."

        $cred = New-Object System.Management.Automation.PSCredential -ArgumentList (((Get-WmiObject Win32_ComputerSystem).Domain + "\$JoinDomainAccountName"), $password)
        Write-Output "Step 6/8 - Creating credentials. Done."

        # Importing AzFilesHybrid module
        $null = Install-PackageProvider Nuget -Force -Scope AllUsers
        Install-Module PowerShellGet, Az -Force -Scope AllUsers
        Write-Output "Step 7/8 - Installing Nuget as package provider and installing PowerShellGet and Az modules. Done."

        # Registering the target storage account with active directory 
        if($OrganizationalUnit)
        {
            $command = { try{ Set-ExecutionPolicy Bypass; New-Item -Path $psModPath -ItemType Directory | Out-Null; Invoke-WebRequest -Uri "https://github.com/Azure-Samples/azure-files-samples/releases/latest/download/AzFilesHybrid.zip" -OutFile $($path + ".zip") -UseBasicParsing | Unblock-File; Expand-Archive -LiteralPath $($path + ".zip") -DestinationPath $path -Force; $psdFile = Import-PowerShellDataFile -Path "$path\AzFilesHybrid.psd1"; $desiredModulePath = "$psModPath\AzFilesHybrid\$($psdFile.ModuleVersion)\"; New-Item -Path $desiredModulePath -ItemType Directory | Out-Null; Copy-Item -Path "$path\AzFilesHybrid.psd1" -Destination $desiredModulePath; Copy-Item -Path "$path\AzFilesHybrid.psm1" -Destination $desiredModulePath; Remove-Item -Path "$path.zip" -Recurse -Force; Import-Module -Name AzFilesHybrid -Global; Get-ADComputer -Filter 'Name -like "*$storageAccountName*"' -ErrorAction Stop }catch{ Connect-AzAccount -Identity -Subscription $subscriptionId; Join-AzStorageAccountForAuth -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName -DomainAccountType 'ComputerAccount' -OrganizationalUnitDistinguishedName $OrganizationalUnit -EncryptionType 'AES256,RC4' }}
        }
        else 
        {
            $command = { try{ Set-ExecutionPolicy Bypass; New-Item -Path $psModPath -ItemType Directory | Out-Null; Invoke-WebRequest -Uri "https://github.com/Azure-Samples/azure-files-samples/releases/latest/download/AzFilesHybrid.zip" -OutFile $($path + ".zip") -UseBasicParsing | Unblock-File; Expand-Archive -LiteralPath $($path + ".zip") -DestinationPath $path -Force; $psdFile = Import-PowerShellDataFile -Path "$path\AzFilesHybrid.psd1"; $desiredModulePath = "$psModPath\AzFilesHybrid\$($psdFile.ModuleVersion)\"; New-Item -Path $desiredModulePath -ItemType Directory | Out-Null; Copy-Item -Path "$path\AzFilesHybrid.psd1" -Destination $desiredModulePath; Copy-Item -Path "$path\AzFilesHybrid.psm1" -Destination $desiredModulePath; Remove-Item -Path "$path.zip" -Recurse -Force; Import-Module -Name AzFilesHybrid -Global; Get-ADComputer -Filter 'Name -like "*$storageAccountName*"' -ErrorAction Stop }catch{ Connect-AzAccount -Identity -Subscription $subscriptionId; Join-AzStorageAccountForAuth -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName -DomainAccountType 'ComputerAccount' -EncryptionType 'AES256,RC4' }}

        }
        # Running as join domain account
        Start-CommandAsDifferentUser $cred $command
        Write-Output "Step 8/8 - Joining storage account to domain. Done."
    }
    catch 
    {
        Write-Error $_.Exception
        throw "Could not add the file share to the domain. Function returned exit code $LASTEXITCODE."
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

    if($AddAzureFileShareToDomain)
    {
        ## Calling function
        Write-Output "Adding Azure File Share to the current domain..."
        $aaftdExitCode = Add-AzureFileShareToDomain $AddAzureFileShareToDomain $JoinDomainAccountName $KeyVaultName $OrganizationalUnit

        if($aaftdExitCode -ne 0)
        {
            throw "Could not add the file share to the domain. Function returned exit code $aaftdExitCode."
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