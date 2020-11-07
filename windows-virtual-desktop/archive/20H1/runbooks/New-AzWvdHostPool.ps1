param ( 

    [Parameter(Mandatory=$true)]   
    [String] $ResourceGroupName,

    [Parameter(Mandatory=$false)]   
    [String] $HostPoolName,

    [Parameter(Mandatory=$false)]   
    [String] $HostPoolType,

    [Parameter(Mandatory=$false)]   
    [String] $LoadBalancerType,

    [Parameter(Mandatory=$false)]   
    [String] $WorkspaceName,

    [Parameter(Mandatory=$false)]   
    [String] $DesktopAppGroupName,

    [Parameter(Mandatory=$false)]   
    [String] $SubscriptionId,

    [Parameter(Mandatory=$false)]   
    [String] $Location
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

## Creating the hostpool
Write-Output "`n------------------------ Status ------------------------" 
Write-Output "Creating the hostpool ..." 

try
{                  
    $hostpool = Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId
    
    if ($hostpool)
    {
        Write-Output -Message "A hostpool has been found with the name $HostPoolName."
    }
    else
    {
        Write-Output "No existing hostpool found. Creating it."

        New-AzWvdHostPool -Name $HostpoolName -ResourceGroupName $ResourcegroupName -HostPoolType $HostPoolType -Location $Location -SubscriptionId $SubscriptionId -LoadBalancerType $LoadBalancerType -DesktopAppGroupName $DesktopAppGroupName -WorkspaceName $WorkspaceName 
    }
}
catch
{
    Write-Error -Message $_.Exception
    throw $_.Exception    
}
## End of creating hostpool

## Link to session host registration