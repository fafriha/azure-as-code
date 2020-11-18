workflow Add-DatadogExtension
{
    ## Parameters
    Param (  
        [Parameter(Mandatory=$true)]
        [object] $recoveryPlanContext
    )
    
    $settings = @{"api_key"= (Get-AutomationVariable -Name 'datadogApiKey')}
    $extensionType = Get-AutomationVariable - Name 'extensionType'
    $publisherName = Get-AutomationVariable - Name 'publisherName'
    $automationAccountName = Get-AutomationVariable - Name 'automationaccountName'
    $location = Get-AutomationVariable - Name 'location'

    ## Start of Connect to Azure
    Write-Output "Connecting to Azure ..."

    try
    {
        $connectionName = "AzureRunAsConnection"

        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

        $null = Add-AzureRmAccount `
                    -ServicePrincipal `
                    -TenantId $servicePrincipalConnection.TenantId `
                    -ApplicationId $servicePrincipalConnection.ApplicationId `
                    -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

        Write-Output "Successfully connected to Azure." 
    } 
    catch
    {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } 
        else
        {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
    ## End of Connect to Azure
    
    # Start of Get properties
    Write-Output "Getting properties ..."

    try
    {
        ## Get virtual machines properties
        $VMinfo = $recoveryPlanContext.VmMap | Get-Member | Where-Object MemberType -EQ NoteProperty | select -ExpandProperty Name
        $vmMap = $recoveryPlanContext.VmMap
        
        foreach($VMID in $VMinfo)
        {
            $VM = $vmMap.$VMID                
            $resourceGroupName += $VM.ResourceGroupName
            $vmNames += $VM.RoleName
        }

        Write-Output "Retrieved all virtual machines."

        ## Get extension properties       
        $extensions = (Get-AzureRmVMExtensionImage -Location $location -PublisherName $publisherName -Type $extensionType) | Sort-Object  -Property Version -Descending
        $extension = $extensions[0] 

        ## Remove '0' if it is the last version's number
        if ($extension.Version -match '.0$')
        {
            $version = $extension.Version -replace ".{2}$"
        }
        elseif ($extension.Version -match '0$')
        {
            $version = $extension.Version -replace ".{1}$"
        }
        
        Write-Output "The latest extension version found for $extensionType is $version."
    }
    catch 
    {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
    # End of Get properties
    
    # Start of Set extensions
    Write-Output "Deploying extension ..."

    try 
    {               
        foreach -parallel ($vmName in $vmNames)
        {
            $nodeCodefigurationName = InlineScript {
                switch -Wildcard ($vmName)
                {
                    "*sql*"
                    {
                        $nodeConfigurationName = "datadog.sqlserver"
                    }
                    "*iis*"
                    {
                        $nodeConfigurationName = "datadog.iis"
                    }
                    "*dc*"
                    {
                        $nodeConfigurationName = "datadog.domaincontrollers"
                    }
                    "default"
                    {
                        $nodeConfigurationName = "datadog.default"
                    }
                }

                return $nodeCodefigurationName
            }

            Write-Output "Adding the $extensionType version $version to the virtual machine $vmName ..."

            $workflow:null = Set-AzureRmVMExtension -ResourceGroupName $resourceGroupName -Location $location -VMName $vmName -Publisher $($extension.PublisherName) -ExtensionType $($extension.Type) -TypeHandlerVersion $version -Name "EMS-$extensionType" -Settings $settings
            
            Write-Output "Registering virtual machine $vmName to the node configuration $nodeConfigurationName ..."

            $workflow:null = Register-AzureRmAutomationDscNode -AutomationAccountName $automationAccountName -AzureVMName $vmName -ResourceGroupName $resourceGroupName -NodeConfigurationName $nodeConfigurationName
        }
       
        Write-Output "Successfully added the extensions."

    }
    catch 
    {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
    # End of Set extension
}