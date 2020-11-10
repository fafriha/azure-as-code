<#
.SYNOPSIS
  This Runbook helps managing Azure AD applications optimally.

.DESCRIPTION
  This Runbook connects to Azure AD with the Azure Run As account, retrieves all relevant information about all Azure AD 
  applications in the current tenant and exports the output in a more readable way to a file within a storage account.

.PARAMETER StorageAccountName
  A storage account to store the outputs.

.PARAMETER ContainerName
  A container that will be created within the specified storage account.

.PARAMETER ResourceGroupeName
  A resource group containing the specified storage account.

.PARAMETER Location
  A location to host the storage account.

.OUTPUTS
  Output file named AppsWithCreds-<date>.csv stored in the specified storage account.

.NOTES
  Version:        1.0
  Author:         Farouk Friha
  Creation Date:  07/22/2019
  Purpose/Change: Initial script development
#>

#-------------------------------------------------------------[Parameters]------------------------------------------------------

Param (

    [Parameter(Mandatory=$true)]  
    [String]$StorageAccountName,

    [Parameter(Mandatory=$true)]  
    [String]$ResourceGroupName,

    [Parameter(Mandatory=$true)]  
    [String]$ContainerName,

    [Parameter(Mandatory=$true)]  
    [String]$Location
)

#---------------------------------------------------------[Initializations]-----------------------------------------------------

$ErrorActionPreference = "Continue"
$credsInventory = @()
$path = "AppsWithCredentials-" + (Get-Date).ToString("MMddyyyy") + ".csv"

#----------------------------------------------------------[Functions]----------------------------------------------------------

Function Sort-Credentials ($App, $Creds, $Owner, $CredsType)
{
    if((Get-Date) -gt $($creds.EndDate))
    {
        $Status = "Expired"
    }
    else
    {
        $status = "Active"
    }

    $output += [PSCustomObject] @{
        Name = $app.DisplayName
        ObjectId = $app.ObjectId
        AppId = $app.AppId
        Crendentials = $credsType
        Start = ($creds.StartDate).ToString("MM/dd/yyyy")
        End = ($creds.EndDate).ToString("MM/dd/yyyy")
        Owner = $owner.DisplayName
        Publisher = $owner.PublisherName
        Contact  = $owner.UserPrincipalName
        Status = $Status

    }

    return $output
}

#----------------------------------------------------------[Execution]----------------------------------------------------------

try
{
    ## Authentication
    Write-Output ""
    Write-Output "------------------------ Authentication ------------------------"
    Write-Output "Logging in to Azure and Azure AD ..."

    $Conn = Get-AutomationConnection -Name AzureRunAsConnection
    
    $null = Connect-AzureAD `
                    -TenantId $Conn.TenantID `
                    -ApplicationId $Conn.ApplicationID `
                    -CertificateThumbprint $Conn.CertificateThumbprint

    # Ensures you do not inherit an AzContext in your runbook
    $null = Disable-AzContextAutosave -Scope Process
    
    $null = Connect-AzAccount `
                    -ServicePrincipal `
                    -Tenant $Conn.TenantID `
                    -ApplicationId $Conn.ApplicationID `
                    -CertificateThumbprint $Conn.CertificateThumbprint

    Write-Output "Successfully logged in to Azure and Azure AD." 
} 
catch
{
    if (!$Conn)
    {
        $ErrorMessage = "Service principal not found."
        throw $ErrorMessage
    } 
    else
    {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
## End of authentication

## Get all Azure AD applications
try
{
    Write-Output ""
    Write-Output "------------------------ Status ------------------------"
    Write-Output "Getting all Azure AD applications ..."

    $apps = Get-AzureADApplication
    
    Write-Output "Done."
    Write-Output "Formatting output ..."
}
catch
{
    if (!$apps)
    {
        Write-Error "No applications found."
    }
    else
    {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
## End of getting Azure AD applications

## Extract information from each application
try
{
    foreach ($app in $apps)
    {                                                                                                                                                                                                                                                                                    
        $owner = Get-AzureADApplicationOwner -ObjectId $app.ObjectId

        if ($app.KeyCredentials)
        {
            foreach ($creds in $app.KeyCredentials)
            {
                $credsInventory += Sort-Credentials -App $app -Creds $creds -Owner $owner -CredsType "Certificate"
            } 
        }

        if ($app.PasswordCredentials)
        {
            foreach ($creds in $app.PasswordCredentials)
            {
                $credsInventory += Sort-Credentials -App $app -Creds $creds -Owner $owner -CredsType "Client secret"
            } 
        }
    }

    Write-Output "Done."
}
catch
{
    Write-Error -Message $_.Exception
    throw $_.Exception    
}

## Display and show all applications with credentials
try
{
    Write-Output "Listing all applications with credentials ..."

    $credsInventory

    Write-Output "Done."

    ## Export to the specified storage account
    
    if (!(Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue))
    {
        $storageAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $Location -SkuName Standard_LRS -Kind StorageV2
        $ctx = $storageAccount.Context
    }
    else
    { 
        $storageAccountKey = (Get-AzStorageAccountKey -Name $StorageAccountName -ResourceGroupName $resourceGroupName).Value[0]
        $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageAccountKey 
    }

    if(!(Get-AzStorageContainer -Name $containerName -Context $ctx -ErrorAction Silentlycontinue))
    {
        Write-Output "Creating container ..."

        $null = New-AzStorageContainer -Name $containerName -Context $ctx -Permission blob

        Write-Output "Done."
    }

    Write-Output "Exporting to CSV files ..."

    $credsInventory | Export-Csv $path -NoTypeInformation -Delimiter ";"
    $null = Set-AzStorageBlobContent -Container $containerName -File $path -Blob $path -Context $ctx -Force

    Write-Output "Done."
}
catch
{
    Write-Error -Message $_.Exception
    throw $_.Exception     
}
## End of export