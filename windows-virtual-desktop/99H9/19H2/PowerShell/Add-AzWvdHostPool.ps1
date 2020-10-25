param ( 

    [Parameter(Mandatory=$true)]   
    [String] $WorkspaceName,

    [Parameter(Mandatory=$true)]   
    [String] $HostPoolName,

    [Parameter(Mandatory=$true)]   
    [String] $HostPoolType,

    [Parameter(Mandatory=$true)]   
    [String] $LoadBalancerType,

    [Parameter(Mandatory=$true)]   
    [String] $Location,

    [Parameter(Mandatory=$true)]   
    [String] $DesktopAppGroupName,

    [Parameter(Mandatory=$true)]   
    [String] $AutomationAccountName,

    [Parameter(Mandatory=$true)]   
    [String] $ResourceGroupName,

    [Parameter(Mandatory=$false)]   
    [Boolean] $IsValidationeEnv = $false,

    [Parameter(Mandatory=$false)]   
    [String] $TagName, 
 
    [Parameter(Mandatory=$false)] 
    [String] $TagValue 
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

## Creating the host pool
Write-Output "`n------------------------ Status ------------------------" 
Write-Output "Creating the host pool in workspace $WorkspaceName ..." 

try
{
    $workspace = Get-AzWvdWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName

    if (!$workspace)
    {
        Write-Output "The specified workspace does not exists."
        Write-Output "Creating the workspace ..."

        New-AzWvdWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -Location $Location

        Write-Output "successfully created the workspace $WorkspaceName in the resource group $ResourceGroupName."
    }

    $hostPool = Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $resourceGroupName

    if ($hostPool)
    {
        Write-Output "The host pool $HostPoolName already exists."
    }
    else
    {
        New-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -WorkspaceName $WorkspaceName -HostPoolType $HostPoolType -Location $Location -DesktopAppGroupName $DesktopAppGroupName -ValidationEnvironment $IsValidationeEnv
        Write-Output -Message "Successfully created the host pool $HostPoolName in the worskpace $WorkspaceName and the desktop app group $DesktopAppGroupName."
    }
}
catch
{
    Write-Error -Message $_.Exception
    throw $_.Exception    
}
## End of creatinh the host pool