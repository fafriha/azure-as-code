param ( 

    [Parameter(Mandatory=$true)]   
    [String] $ResourceGroupName,

    [Parameter(Mandatory=$false)]   
    [String] $WorkspaceName,

    [Parameter(Mandatory=$false)]   
    [String] $SubscriptionId,

    [Parameter(Mandatory=$false)]   
    [String] $Location,

    [Parameter(Mandatory=$false)]   
    [String] $Description,

    [Parameter(Mandatory=$false)]   
    [String] $FriendlyName
)

## Authentication 
Write-Output "`n------------------------ Authentication ------------------------" 
Write-Output "Sign in to Azure ..." 
 
try 
{ 
    # Ensures you do not inherit an AzContext in your runbook 
    $null = Disable-AzContextAutosave –Scope Process 
    $Conn = Get-AutomationConnection -Name AzureRunAsConnection

    $null = Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
    
    Write-Output "Successfully signed in to Azure."  
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

## Creating the workspace
Write-Output "`n------------------------ Status ------------------------" 
Write-Output "Creating the workspace ..." 

try
{                  
    $workspace = Get-AzWvdWorkspace -Name $WorkspaceName -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId
    
    if ($workspace)
    {
        Write-Output -Message "A workspace has been found with the name $workspaceName."
    }
    else
    {
        Write-Output "No existing workspace found. Creating it."

        New-AzWvdWorkspace -Name $WorkspaceName -ResourceGroupName $ResourcegroupName -Location $Location -SubscriptionId $SubscriptionId -Description $Description -FriendlyName $FriendlyName
    }
}
catch
{
    Write-Error -Message $_.Exception
    throw $_.Exception    
}
## End of creating workspace

#Link to host pool creation