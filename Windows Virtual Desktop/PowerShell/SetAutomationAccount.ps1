#Requires -RunAsAdministrator
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
	[string]$SubscriptionId,

	[Parameter(mandatory = $True)]
	[string]$AADTenantId,

	[Parameter(mandatory = $True)]
	[string]$SvcPrincipalApplicationId,

	[Parameter(mandatory = $True)]
	[string]$SvcPrincipalSecret,

	[Parameter(mandatory = $False)]
	[string]$ResourceGroupName,

	[Parameter(mandatory = $False)]
	$AutomationAccountName,

	[Parameter(mandatory = $False)]
	$RunbookName,

	[Parameter(mandatory = $False)]
	$WebhookName,

	[Parameter(mandatory = $False)]
	[string]$Location,

	[Parameter(mandatory = $False)]
	[string]$WorkspaceName,

	[Parameter(Mandatory = $true)]
	[String] $SelfSignedCertPlainPassword,

	[Parameter(Mandatory = $false)]
	[ValidateSet("AzureCloud", "AzureUSGovernment")]
	[string]$EnvironmentName = "AzureCloud",

	[Parameter(Mandatory = $false)]
	[int] $SelfSignedCertNoOfMonthsUntilExpired = 12
)

# Set the ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser -Force -Confirm:$false


# Setting ErrorActionPreference to stop script execution when error occurs
$ErrorActionPreference = "Stop"

# Install and import Az and AzureAD modules
Write-Output "Setting PSRepository and installing Az modules"
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module Az -AllowClobber -Confirm:$False -Force
Import-Module Az.Resources
Import-Module Az.Accounts
Import-Module Az.OperationalInsights
Import-Module Az.Automation

$SvcPrincipalSecuredSecret = $SvcPrincipalSecret | ConvertTo-SecureString -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential -ArgumentList ($SvcPrincipalApplicationId, $SvcPrincipalSecuredSecret)

Connect-AzAccount -ServicePrincipal -Credential $Creds -Tenant $AADTenantId 

# Get the azure context
$Context = Get-AzContext
if ($Context -eq $null)
{
	Write-Error "Please authenticate to Azure using Connect-AzAccount cmdlet and then run this script"
	exit
}

# Select the subscription
$Subscription = Select-azSubscription -SubscriptionId $SubscriptionId
Set-AzContext -SubscriptionObject $Subscription.ExtendedProperties

# Get the Role Assignment of the authenticated user
$RoleAssignment = (Get-AzRoleAssignment -ServicePrincipalName $SvcPrincipalApplicationId)

if ($RoleAssignment.RoleDefinitionName -eq "Owner" -or $RoleAssignment.RoleDefinitionName -eq "Contributor")
{
	#Check if the resourcegroup exist
	$ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue
	if ($ResourceGroup -eq $null) {
		New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Force -Verbose
		Write-Output "Resource Group was created with name $ResourceGroupName"
	}

	#Check if the Automation Account exist
	$AutomationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -ErrorAction SilentlyContinue
	if ($AutomationAccount -eq $null) {
		New-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -Location $Location -Plan Free -Verbose
		Write-Output "Automation Account was created with name $AutomationAccountName"
	}

	$RequiredModules = @(
		[pscustomobject]@{ ModuleName = 'Az.Accounts'; ModuleVersion = '1.6.4' }
		[pscustomobject]@{ ModuleName = 'Microsoft.RDInfra.RDPowershell'; ModuleVersion = '1.0.1288.1' }
		[pscustomobject]@{ ModuleName = 'OMSIngestionAPI'; ModuleVersion = '1.6.0' }
		[pscustomobject]@{ ModuleName = 'Az.Compute'; ModuleVersion = '3.1.0' }
		[pscustomobject]@{ ModuleName = 'Az.Resources'; ModuleVersion = '1.8.0' }
		[pscustomobject]@{ ModuleName = 'Az.Automation'; ModuleVersion = '1.3.4' }
	)

	#Function to add required modules to Azure Automation account
	function AddingModules-toAutomationAccount {
		param(
			[Parameter(mandatory = $true)]
			[string]$ResourceGroupName,

			[Parameter(mandatory = $true)]
			[string]$AutomationAccountName,

			[Parameter(mandatory = $true)]
			[string]$ModuleName,

			# if not specified latest version will be imported
			[Parameter(mandatory = $false)]
			[string]$ModuleVersion
		)


		$Url = "https://www.powershellgallery.com/api/v2/Search()?`$filter=IsLatestVersion&searchTerm=%27$ModuleName $ModuleVersion%27&targetFramework=%27%27&includePrerelease=false&`$skip=0&`$top=40"

		[array]$SearchResult = Invoke-RestMethod -Method Get -Uri $Url
		if ($SearchResult.Count -ne 1) {
			$SearchResult = $SearchResult[0]
		}

		if (!$SearchResult) {
			Write-Error "Could not find module '$ModuleName' on PowerShell Gallery."
		}
		elseif ($SearchResult.Count -and $SearchResult.Length -gt 1) {
			Write-Error "Module name '$ModuleName' returned multiple results. Please specify an exact module name."
		}
		else {
			$PackageDetails = Invoke-RestMethod -Method Get -Uri $SearchResult.Id

			if (!$ModuleVersion) {
				$ModuleVersion = $PackageDetails.entry.properties.version
			}

			$ModuleContentUrl = "https://www.powershellgallery.com/api/v2/package/$ModuleName/$ModuleVersion"

			# Test if the module/version combination exists
			try {
				Invoke-RestMethod $ModuleContentUrl -ErrorAction Stop | Out-Null
				$Stop = $False
			}
			catch {
				Write-Error "Module with name '$ModuleName' of version '$ModuleVersion' does not exist. Are you sure the version specified is correct?"
				$Stop = $True
			}

			if (!$Stop) {

				# Find the actual blob storage location of the module
				do {
					$ActualUrl = $ModuleContentUrl
					$ModuleContentUrl = (Invoke-WebRequest -Uri $ModuleContentUrl -MaximumRedirection 0 -UseBasicParsing -ErrorAction Ignore).Headers.Location
				} while ($ModuleContentUrl -ne $Null)

				New-AzAutomationModule `
 					-ResourceGroupName $ResourceGroupName `
 					-AutomationAccountName $AutomationAccountName `
 					-Name $ModuleName `
 					-ContentLink $ActualUrl
			}
		}
	}

	#Function to check if the module is imported
	function Check-IfModuleIsImported {
		param(
			[Parameter(mandatory = $true)]
			[string]$ResourceGroupName,

			[Parameter(mandatory = $true)]
			[string]$AutomationAccountName,

			[Parameter(mandatory = $true)]
			[string]$ModuleName
		)

		$IsModuleImported = $false
		while (!$IsModuleImported) {
			$IsModule = Get-AzAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $ModuleName -ErrorAction SilentlyContinue
			if ($IsModule.ProvisioningState -eq "Succeeded") {
				$IsModuleImported = $true
				Write-Output "Successfully imported $ModuleName module into Automation Account modules..."
			}
			else {
				Write-Output "Waiting for import module $ModuleName into Automation Account modules ..."
			}
		}
	}

    #Check if the Webhook URI exists in automation variable
    $WebhookURI = Get-AzAutomationVariable -Name "WebhookURI" -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction SilentlyContinue
    if (!$WebhookURI) {
        $Webhook = New-AzAutomationWebhook -Name $WebhookName -RunbookName $runbookName -IsEnabled $True -ExpiryTime (Get-Date).AddYears(5) -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Force
        Write-Output "Automation Account Webhook is created with name '$WebhookName'"
        $URIofWebhook = $Webhook.WebhookURI | Out-String
        New-AzAutomationVariable -Name "WebhookURI" -Encrypted $false -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Value $URIofWebhook
        Write-Output "Webhook URI stored in Azure Automation Acccount variables"
        $WebhookURI = Get-AzAutomationVariable -Name "WebhookURI" -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction SilentlyContinue
    }

	# Required modules imported from Automation Account Modules gallery for Scale Script execution
	# foreach ($Module in $RequiredModules) {
	# 	# Check if the required modules are imported 
	# 	$ImportedModule = Get-AzAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $Module.ModuleName -ErrorAction SilentlyContinue
	# 	if ($ImportedModule -eq $Null) {
	# 		AddingModules-toAutomationAccount -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ModuleName $Module.ModuleName
	# 		Check-IfModuleIsImported -ModuleName $Module.ModuleName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
	# 	}
	# 	elseif ($ImportedModule.version -ne $Module.ModuleVersion) {
	# 		AddingModules-toAutomationAccount -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ModuleName $Module.ModuleName
	# 		Check-IfModuleIsImported -ModuleName $Module.ModuleName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
	# 	}
	# }

    function CreateSelfSignedCertificate([string] $certificateName, [string] $selfSignedCertPlainPassword,
        [string] $certPath, [string] $certPathCer, [string] $selfSignedCertNoOfMonthsUntilExpired ) {
        $Cert = New-SelfSignedCertificate -DnsName $certificateName -CertStoreLocation cert:\LocalMachine\My `
            -KeyExportPolicy Exportable -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
            -NotAfter (Get-Date).AddMonths($selfSignedCertNoOfMonthsUntilExpired) -HashAlgorithm SHA256

        $CertPassword = ConvertTo-SecureString $selfSignedCertPlainPassword -AsPlainText -Force
        Export-PfxCertificate -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) -FilePath $certPath -Password $CertPassword -Force | Write-Verbose
        Export-Certificate -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) -FilePath $certPathCer -Type CERT | Write-Verbose
    }

    function CreateServicePrincipal([System.Security.Cryptography.X509Certificates.X509Certificate2] $PfxCert, [string] $connectionassetname) {
        $keyValue = [System.Convert]::ToBase64String($PfxCert.GetRawCertData())
        $keyId = (New-Guid).Guid

        # Create an Azure AD application, AD App Credential, AD ServicePrincipal

        # Requires Application Developer Role, but works with Application administrator or GLOBAL ADMIN
        $Application = New-AzADApplication -DisplayName $connectionassetname -HomePage ("http://" + $connectionassetname) -IdentifierUris ("http://" + $keyId)
        # Requires Application administrator or GLOBAL ADMIN
        $ApplicationCredential = New-AzADAppCredential -ApplicationId $Application.ApplicationId -CertValue $keyValue -StartDate $PfxCert.NotBefore -EndDate $PfxCert.NotAfter
        # Requires Application administrator or GLOBAL ADMIN
        $ServicePrincipal = New-AzADServicePrincipal -ApplicationId $Application.ApplicationId
        $GetServicePrincipal = Get-AzADServicePrincipal -ObjectId $ServicePrincipal.Id

        # Sleep here for a few seconds to allow the service principal application to become active (ordinarily takes a few seconds)
        Sleep -s 15
		# Requires User Access Administrator or Owner.
		
        $RoleExists = Get-AzRoleAssignment -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue

        if (!$RoleExists) {
            New-AzRoleAssignment -RoleDefinitionName Contributor -ApplicationId $Application.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue
        }
        return $Application.ApplicationId.ToString();
    }

    function CreateAutomationCertificateAsset ([string] $resourceGroupName, [string] $automationAccountName, [string] $certifcateAssetName, [string] $certPath, [string] $certPlainPassword, [Boolean] $Exportable) {
        $CertPassword = ConvertTo-SecureString $certPlainPassword -AsPlainText -Force
        Remove-AzAutomationCertificate -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $certifcateAssetName -ErrorAction SilentlyContinue
        New-AzAutomationCertificate -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Path $certPath -Name $certifcateAssetName -Password $CertPassword -Exportable:$Exportable  | write-verbose
    }

    function CreateAutomationConnectionAsset ([string] $resourceGroupName, [string] $automationAccountName, [string] $connectionAssetName, [string] $connectionTypeName, [System.Collections.Hashtable] $connectionFieldValues ) {
        Remove-AzAutomationConnection -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $connectionAssetName -Force -ErrorAction SilentlyContinue
        New-AzAutomationConnection -ResourceGroupName $ResourceGroupName -AutomationAccountName $automationAccountName -Name $connectionAssetName -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues
    }

    Import-Module Az.Automation
    Enable-AzureRmAlias

    # Create a Run As account by using a service principal
    $CertifcateAssetName = "AzureRunAsCertificate"
    $ConnectionAssetName = "AzureRunAsConnection"
    $ConnectionTypeName = "AzureServicePrincipal"

    if ($EnterpriseCertPathForRunAsAccount -and $EnterpriseCertPlainPasswordForRunAsAccount) {
        $PfxCertPathForRunAsAccount = $EnterpriseCertPathForRunAsAccount
        $PfxCertPlainPasswordForRunAsAccount = $EnterpriseCertPlainPasswordForRunAsAccount
    }
    else {
        $CertificateName = $AutomationAccountName + $CertifcateAssetName
        $PfxCertPathForRunAsAccount = Join-Path $env:TEMP ($CertificateName + ".pfx")
        $PfxCertPlainPasswordForRunAsAccount = $SelfSignedCertPlainPassword
        $CerCertPathForRunAsAccount = Join-Path $env:TEMP ($CertificateName + ".cer")
        CreateSelfSignedCertificate $CertificateName $PfxCertPlainPasswordForRunAsAccount $PfxCertPathForRunAsAccount $CerCertPathForRunAsAccount $SelfSignedCertNoOfMonthsUntilExpired
    }

    # Create a service principal
    $PfxCert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($PfxCertPathForRunAsAccount, $PfxCertPlainPasswordForRunAsAccount)
    $ApplicationId = CreateServicePrincipal $PfxCert $connectionassetname

    # Create the Automation certificate asset
    CreateAutomationCertificateAsset $ResourceGroupName $AutomationAccountName $CertifcateAssetName $PfxCertPathForRunAsAccount $PfxCertPlainPasswordForRunAsAccount $true

    # Populate the ConnectionFieldValues
    $SubscriptionInfo = Get-AzSubscription -SubscriptionId $SubscriptionId
    $TenantID = $SubscriptionInfo | Select TenantId -First 1
    $Thumbprint = $PfxCert.Thumbprint
    $ConnectionFieldValues = @{"ApplicationId" = $ApplicationId; "TenantId" = $TenantID.TenantId; "CertificateThumbprint" = $Thumbprint; "SubscriptionId" = $SubscriptionId}

    # Create an Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal.
    CreateAutomationConnectionAsset $ResourceGroupName $AutomationAccountName $ConnectionAssetName $ConnectionTypeName $ConnectionFieldValues

    if ($CreateClassicRunAsAccount) {
        # Create a Run As account by using a service principal
        $ClassicRunAsAccountCertifcateAssetName = "AzureClassicRunAsCertificate"
        $ClassicRunAsAccountConnectionAssetName = "AzureClassicRunAsConnection"
        $ClassicRunAsAccountConnectionTypeName = "AzureClassicCertificate "
        $UploadMessage = "Please upload the .cer format of #CERT# to the Management store by following the steps below." + [Environment]::NewLine +
        "Log in to the Microsoft Azure portal (https://portal.azure.com) and select Subscriptions -> Management Certificates." + [Environment]::NewLine +
        "Then click Upload and upload the .cer format of #CERT#"

        if ($EnterpriseCertPathForClassicRunAsAccount -and $EnterpriseCertPlainPasswordForClassicRunAsAccount ) {
            $PfxCertPathForClassicRunAsAccount = $EnterpriseCertPathForClassicRunAsAccount
            $PfxCertPlainPasswordForClassicRunAsAccount = $EnterpriseCertPlainPasswordForClassicRunAsAccount
            $UploadMessage = $UploadMessage.Replace("#CERT#", $PfxCertPathForClassicRunAsAccount)
        }
        else {
            $ClassicRunAsAccountCertificateName = $AutomationAccountName + $ClassicRunAsAccountCertifcateAssetName
            $PfxCertPathForClassicRunAsAccount = Join-Path $env:TEMP ($ClassicRunAsAccountCertificateName + ".pfx")
            $PfxCertPlainPasswordForClassicRunAsAccount = $SelfSignedCertPlainPassword
            $CerCertPathForClassicRunAsAccount = Join-Path $env:TEMP ($ClassicRunAsAccountCertificateName + ".cer")
            $UploadMessage = $UploadMessage.Replace("#CERT#", $CerCertPathForClassicRunAsAccount)
            CreateSelfSignedCertificate $ClassicRunAsAccountCertificateName $PfxCertPlainPasswordForClassicRunAsAccount $PfxCertPathForClassicRunAsAccount $CerCertPathForClassicRunAsAccount $SelfSignedCertNoOfMonthsUntilExpired
        }

        # Create the Automation certificate asset
        CreateAutomationCertificateAsset $ResourceGroupName $AutomationAccountName $ClassicRunAsAccountCertifcateAssetName $PfxCertPathForClassicRunAsAccount $PfxCertPlainPasswordForClassicRunAsAccount $false

        # Populate the ConnectionFieldValues
        $SubscriptionName = $subscription.Subscription.Name
        $ClassicRunAsAccountConnectionFieldValues = @{"SubscriptionName" = $SubscriptionName; "SubscriptionId" = $SubscriptionId; "CertificateAssetName" = $ClassicRunAsAccountCertifcateAssetName}

        # Create an Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal.
        CreateAutomationConnectionAsset $ResourceGroupName $AutomationAccountName $ClassicRunAsAccountConnectionAssetName $ClassicRunAsAccountConnectionTypeName   $ClassicRunAsAccountConnectionFieldValues

        Write-Host -ForegroundColor red       $UploadMessage
	}
	
	if ($WorkspaceName) {
		#Check if the log analytics workspace exists
		$LAWorkspace = Get-AzOperationalInsightsWorkspace | Where-Object { $_.Name -eq $WorkspaceName }
		if (!$LAWorkspace) {
			Write-Error "Provided log analytics workspace doesn't exist in your Subscription."
			exit
		}
		$WorkSpace = Get-AzOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $LAWorkspace.ResourceGroupName -Name $WorkspaceName -WarningAction Ignore
		$LogAnalyticsPrimaryKey = $Workspace.PrimarySharedKey
		$LogAnalyticsWorkspaceId = (Get-AzOperationalInsightsWorkspace -ResourceGroupName $LAWorkspace.ResourceGroupName -Name $workspaceName).CustomerId.GUID

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
	} else {
		Write-Output "Automation Account Name:$AutomationAccountName"
		Write-Output "Webhook URI: $($WebhookURI.value)"
	}
}
else
{
	Write-Output "Authenticated user should have the Owner/Contributor permissions"
}