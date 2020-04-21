<#
.SYNOPSIS
	This is a sample script for to deploy the required resources to execute scaling script in Microsoft Azure Automation Account.
.DESCRIPTION
	This sample script will create the scale script execution required resources in Microsoft Azure. Resources are resourcegroup,automation account,automation account runbook, 
    automation account webhook, log analytic workspace and with customtables.
    Run this PowerShell script in adminstrator mode
    This script depends  Az PowerShell module. To install Az module execute the following commands. Use "-AllowClobber" parameter if you have more than one version of PowerShell modules installed.
	
    PS C:\>Install-Module Az  -AllowClobber

.PARAMETER SubscriptionId
 Required
 Provide Subscription Id of the Azure.

.PARAMETER ResourcegroupName
 Optional
 Name of the resource group to use
 If the group does not exist it will be created
 
.PARAMETER AutomationAccountName
 Optional
 Provide the name of the automation account name do you want create.

.PARAMETER Location
 Optional
 The datacenter location of the resources

.PARAMETER WorkspaceName
 Optional
 Provide name of the log analytic workspace.

.NOTES
If you providing existing automation account. You need provide existing automation account ResourceGroupName for ResourceGroupName parameter.
 
 Example: .\setautomationaccount.ps1 -SubscriptionID "Your Azure SubscriptionID" -ResourceGroupName "Name of the resource group" -AutomationAccountName "Name of the automation account name" -Location "The datacenter location of the resources" -WorkspaceName "Provide existing log analytic workspace name" -SelfSignedCertPlainPassword <StrongPassword>

#>
param(
	[Parameter(mandatory = $True)]
	[string] $SubscriptionId,

	[Parameter(mandatory = $True)]
	[string] $AADTenantId,

	[Parameter(mandatory = $True)]
	[string] $SvcPrincipalApplicationId,

	[Parameter(mandatory = $True)]
	[string] $SvcPrincipalSecret,

	[Parameter(mandatory = $False)]
	[string] $ResourceGroupName,

	[Parameter(mandatory = $False)]
	[string] $AutomationAccountName,

	[Parameter(mandatory = $False)]
	[string] $Location,

	[Parameter(mandatory = $False)]
	[string] $WorkspaceName,

	[Parameter(Mandatory = $true)]
	[String] $SelfSignedCertPlainPassword,

	[Parameter(Mandatory = $false)]
	[ValidateSet("AzureCloud", "AzureUSGovernment")]
	[string] $EnvironmentName = "AzureCloud"
)

####################### Settings #######################

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force -Confirm:$false

$SvcPrincipalSecuredSecret = $SvcPrincipalSecret | ConvertTo-SecureString -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential -ArgumentList ($SvcPrincipalApplicationId, $SvcPrincipalSecuredSecret)

####################### End of settings #######################

####################### Functions #######################

# Create the function to create the authorization signature
function Build-Signature ($customerId,$sharedKey,$date,$contentLength,$method,$contentType,$resource)
{
	$xHeaders = "x-ms-date:" + $date
	$stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

	$bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
	$keyBytes = [Convert]::FromBase64String($sharedKey)

	$sha256 = New-Object System.Security.Cryptography.HMACSHA256
	$sha256.Key = $keyBytes
	$calculatedHash = $sha256.ComputeHash($bytesToHash)
	$encodedHash = [Convert]::ToBase64String($calculatedHash)
	$authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
	return $authorization
}

# Create the function to create and post the request
function Post-LogAnalyticsData ($customerId,$sharedKey,$body,$logType)
{
	$method = "POST"
	$contentType = "application/json"
	$resource = "/api/logs"
	$rfc1123date = [datetime]::UtcNow.ToString("r")
	$contentLength = $body.Length
	$signature = Build-Signature `
		-customerId $customerId `
		-sharedKey $sharedKey `
		-Date $rfc1123date `
		-contentLength $contentLength `
		-FileName $fileName `
		-Method $method `
		-ContentType $contentType `
		-resource $resource
	$uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

	$headers = @{
		"Authorization" = $signature;
		"Log-Type" = $logType;
		"x-ms-date" = $rfc1123date;
		"time-generated-field" = $TimeStampField;
	}

	$response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
	return $response.StatusCode
}

function CreateSelfSignedCertificate([string] $certificateName, [string] $selfSignedCertPlainPassword, [string] $certPath, [string] $certPathCer) 
{
	$Cert = New-SelfSignedCertificate -DnsName $certificateName -CertStoreLocation cert:\LocalMachine\My `
		-KeyExportPolicy Exportable -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
		-NotAfter (Get-Date).AddMonths(12) -HashAlgorithm SHA256

	$CertPassword = ConvertTo-SecureString $selfSignedCertPlainPassword -AsPlainText -Force
	Export-PfxCertificate -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) -FilePath $certPath -Password $CertPassword -Force | Write-Verbose
	Export-Certificate -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) -FilePath $certPathCer -Type CERT | Write-Verbose
}

function CreateServicePrincipal([System.Security.Cryptography.X509Certificates.X509Certificate2] $PfxCert, [string] $connectionassetname) 
{
	$keyValue = [System.Convert]::ToBase64String($PfxCert.GetRawCertData())
	$keyId = (New-Guid).Guid

	# Create an Azure AD application, AD App Credential, AD ServicePrincipal

	# Requires Application Developer Role, but works with Application administrator or GLOBAL ADMIN
	$Application = New-AzADApplication -DisplayName $connectionassetname -HomePage ("http://" + $connectionassetname) -IdentifierUris ("http://" + $keyId)
	
	# Requires Application administrator or GLOBAL ADMIN
	New-AzADAppCredential -ApplicationId $Application.ApplicationId -CertValue $keyValue -StartDate $PfxCert.NotBefore -EndDate $PfxCert.NotAfter
	
	# Requires Application administrator or GLOBAL ADMIN
	$ServicePrincipal = New-AzADServicePrincipal -ApplicationId $Application.ApplicationId
	Get-AzADServicePrincipal -ObjectId $ServicePrincipal.Id

	# Sleep here for a few seconds to allow the service principal application to become active (ordinarily takes a few seconds)
	Sleep -s 15
	
	# Requires User Access Administrator or Owner.
	$RoleExists = Get-AzRoleAssignment -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue

	if (!$RoleExists) {
		New-AzRoleAssignment -RoleDefinitionName Contributor -ApplicationId $Application.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue
	}
	
	return $Application.ApplicationId.ToString();
}

function CreateAutomationCertificateAsset ([string] $resourceGroupName, [string] $automationAccountName, [string] $certifcateAssetName, [string] $certPath, [string] $certPlainPassword, [Boolean] $Exportable) 
{
	$CertPassword = ConvertTo-SecureString $certPlainPassword -AsPlainText -Force
	Remove-AzAutomationCertificate -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $certifcateAssetName -ErrorAction SilentlyContinue
	New-AzAutomationCertificate -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Path $certPath -Name $certifcateAssetName -Password $CertPassword -Exportable:$Exportable  | write-verbose
}

function CreateAutomationConnectionAsset ([string] $resourceGroupName, [string] $automationAccountName, [string] $connectionAssetName, [string] $connectionTypeName, [System.Collections.Hashtable] $connectionFieldValues ) 
{
	Remove-AzAutomationConnection -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $connectionAssetName -Force -ErrorAction SilentlyContinue
	New-AzAutomationConnection -ResourceGroupName $ResourceGroupName -AutomationAccountName $automationAccountName -Name $connectionAssetName -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues
}

function Load-Module ($ModuleName) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $ModuleName}) {
        write-host "Module $ModuleName is already imported."
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $ModuleName}) {
            Import-Module $ModuleName -Verbose
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $ModuleName | Where-Object {$_.Name -eq $ModuleName}) {
                Install-Module -Name $ModuleName -Force -Verbose -Scope CurrentUser
                Import-Module $ModuleName -Verbose
            }
            else {

                # If module is not imported, not available and not in online gallery then abort
                write-host "Module $ModuleName not imported, not available and not in online gallery, exiting."
                EXIT 1
            }
        }
    }
}

####################### End of functions #######################

####################### Main #######################
#Import modules
$RequiredModules = "Az.Accounts", "Az.Resources", "Az.OperatinalInsights", "Az.Automation"

foreach ($Module in $RequiredModules)
{
	Load-Module $Module
}

Enable-AzureRmAlias

# Connect to Azure
Connect-AzAccount -ServicePrincipal -Credential $Creds -Tenant $AADTenantId 

$Context = Get-AzContext
# Get the azure context
if ($null -eq $Context)
{
	Write-Error "Please authenticate to Azure using Connect-AzAccount cmdlet and then run this script"
	EXIT 1
}

# Select the subscription
$Subscription = Select-AzSubscription -SubscriptionId $SubscriptionId
Set-AzContext -SubscriptionObject $Subscription.ExtendedProperties

# Get the Role Assignment of the authenticated user
$RoleAssignment = (Get-AzRoleAssignment -ServicePrincipalName $SvcPrincipalApplicationId)

if (($RoleAssignment.RoleDefinitionName -eq "Owner") -or ($RoleAssignment.RoleDefinitionName -eq "Contributor" -and "User Access Administrator"))
{
    ###### Create a Run As account by using a service principal ######
    $CertifcateAssetName = "AzureRunAsCertificate"
    $ConnectionAssetName = "AzureRunAsConnection"
    $ConnectionTypeName = "AzureServicePrincipal"

	if ($EnterpriseCertPathForRunAsAccount -and $EnterpriseCertPlainPasswordForRunAsAccount) 
	{
        $PfxCertPathForRunAsAccount = $EnterpriseCertPathForRunAsAccount
        $PfxCertPlainPasswordForRunAsAccount = $EnterpriseCertPlainPasswordForRunAsAccount
    }
	else 
	{
        $CertificateName = $AutomationAccountName + $CertifcateAssetName
        $PfxCertPathForRunAsAccount = Join-Path $env:TEMP ($CertificateName + ".pfx")
        $PfxCertPlainPasswordForRunAsAccount = $SelfSignedCertPlainPassword
        $CerCertPathForRunAsAccount = Join-Path $env:TEMP ($CertificateName + ".cer")
        CreateSelfSignedCertificate $CertificateName $PfxCertPlainPasswordForRunAsAccount $PfxCertPathForRunAsAccount $CerCertPathForRunAsAccount
    }

    # Create a service principal
    $PfxCert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($PfxCertPathForRunAsAccount, $PfxCertPlainPasswordForRunAsAccount)
    $ApplicationId = CreateServicePrincipal $PfxCert $connectionassetname

    # Create the Automation certificate asset
    CreateAutomationCertificateAsset $ResourceGroupName $AutomationAccountName $CertifcateAssetName $PfxCertPathForRunAsAccount $PfxCertPlainPasswordForRunAsAccount $true

    # Populate the ConnectionFieldValues
    $SubscriptionInfo = Get-AzSubscription -SubscriptionId $SubscriptionId
    $TenantID = $SubscriptionInfo | Select-Object TenantId -First 1
    $Thumbprint = $PfxCert.Thumbprint
    $ConnectionFieldValues = @{"ApplicationId" = $ApplicationId; "TenantId" = $TenantID.TenantId; "CertificateThumbprint" = $Thumbprint; "SubscriptionId" = $SubscriptionId}

    # Create an Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal.
    CreateAutomationConnectionAsset $ResourceGroupName $AutomationAccountName $ConnectionAssetName $ConnectionTypeName $ConnectionFieldValues
	
	###### End of Run As account service principal creation ######

	###### Create the webhook and store its uri in an automation variable ######
	
	#Check if the Runbook exists in the automation account
    $Runbook = Get-AzAutomationRunbook -Name "ScaleSessionHosts" -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction SilentlyContinue
	
	if (!$Runbook) 
	{
		$Runbook = Import-AzAutomationRunbook -Path C:\Temp\ScaleSessionHosts.ps1 -ResourceGroup $ResourceGroupName -AutomationAccountName $AutomationAccountName -Type PowerShell -Published
		Write-Output "The runbook is created with name ScaleSessionHosts"
	}

	#Check if the Webhook URI exists in automation variable
	$WebhookURI = Get-AzAutomationVariable -Name "WebhookURI" -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction SilentlyContinue
		
	if (!$WebhookURI) 
	{
		$Webhook = New-AzAutomationWebhook -Name "WebhookURI" -RunbookName "ScaleSessionHosts" -IsEnabled $True -ExpiryTime (Get-Date).AddYears(5) -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Force
		Write-Output "Automation Account Webhook is created with name '$WebhookName'"

		$URIofWebhook = $Webhook.WebhookURI | Out-String
		New-AzAutomationVariable -Name "WebhookURI" -Encrypted $false -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Value $URIofWebhook
		Write-Output "Webhook URI stored in Azure Automation Acccount variables"
	}

	###### End of webhook and automation variable creation ######

	###### Send automation account logs to log analytics ######
	
	if ($WorkspaceName) 
	{
		#Check if the log analytics workspace exists
		$LAWorkspace = Get-AzOperationalInsightsWorkspace | Where-Object { $_.Name -eq $WorkspaceName }
		
		if (!$LAWorkspace) 
		{
			Write-Error "Provided log analytics workspace doesn't exist in your Subscription."
			EXIT 1
		}

		$WorkSpace = Get-AzOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $LAWorkspace.ResourceGroupName -Name $WorkspaceName -WarningAction Ignore
		$LogAnalyticsPrimaryKey = $Workspace.PrimarySharedKey
		$LogAnalyticsWorkspaceId = (Get-AzOperationalInsightsWorkspace -ResourceGroupName $LAWorkspace.ResourceGroupName -Name $workspaceName).CustomerId.GUID

		# Specify the name of the record type that you'll be creating
		$TenantScaleLogType = "WVDTenantScale_CL"

		# Specify a field with the created time for the records
		$TimeStampField = Get-Date
		$TimeStampField = $TimeStampField.GetDateTimeFormats(115)

		# Submit the data to the API endpoint

		#Custom WVDTenantScale Table
		$CustomLogWVDTenantScale = @"
[
    {
    "hostpoolName": " ",
    "logmessage": " "
    }
]
"@

		Post-LogAnalyticsData -customerId $LogAnalyticsWorkspaceId -sharedKey $LogAnalyticsPrimaryKey -Body ([System.Text.Encoding]::UTF8.GetBytes($CustomLogWVDTenantScale)) -logType $TenantScaleLogType

		Write-Output "Log Analytics workspace id:$LogAnalyticsWorkspaceId"
		Write-Output "Log Analytics workspace primarykey:$LogAnalyticsPrimaryKey"
		Write-Output "Automation Account Name:$AutomationAccountName"
		Write-Output "Webhook URI: $($WebhookURI.value)"
	} 
	else 
	{
		Write-Output "Automation Account Name:$AutomationAccountName"
		Write-Output "Webhook URI: $($WebhookURI.value)"
	}

	###### End of sending automation account logs to log analytics ######

}
else
{
	Write-Output "Authenticated user should have the Owner/Contributor permissions"
	EXIT 1
}

####################### End of main #######################