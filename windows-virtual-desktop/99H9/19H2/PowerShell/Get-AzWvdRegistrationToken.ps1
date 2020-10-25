param ( 

    [Parameter(Mandatory=$true)]   
    [String] $AutomationAccountName,

    [Parameter(Mandatory=$true)]   
    [String] $ResourceGroupName,

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

## Getting all host pools and their registration token
Write-Output "`n------------------------ Status ------------------------" 
Write-Output "Getting all host pools ..." 

try
{
    if ($TagName)
    {                    
        $hostPools = Get-AzWvdHostPool -TagName $TagName -TagValue $TagValue
        
        if ($hostPools)
        {
            $result = @()
                                      
            foreach ($hostPool in $hostPools)
            {
                $resourceGroupName = ($hostPool.Id).split('/')[4]
                $hostPoolName = $hostPool.Name
                $hostPoolLocation = $hostPool.Location

                $registrationToken = New-AzWvdRegistrationInfo -ResourceGroupName $resourceGroupName -HostPoolName $hostPoolName -ExpirationTime $((get-date).ToUniversalTime().AddDays(7).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
                
                if (!$registrationToken)
                {
                    $registrationToken = Get-AzWvdRegistrationInfo -ResourceGroupName $resourceGroupName -HostPoolName $hostPoolNamee
                }
            
                $obj = $registrationToken | Out-String
                                    
                $result = New-Object -Type PSObject -Property @{
                    "Host pool name" = $hostPool.Name
                    "Resource group name" = ($hostPool.Id).split('/')[4]
                    "Location" = $hostPool.Location
                    "Registration token" = $obj
                    $TagName = $TagValue
                }

                $result += $result

                New-AzAutomationVariable -AutomationAccountName $AutomationAccountName -Name $hostPoolName-token -Encrypted $False -Value $obj -ResourceGroupName $ResourceGroupName

                Write-Output -Message "Saved registration token into the automation variable $WVDHostPoolName-token: $obj"
            }
        }
        else
        {
            Write-Output "No host pool found with the tag $TagName"
        }
    }       
    else
    {
        $hostPools = Get-AzWvdHostPool
        
        if ($hostPools)
        {
            $result = @()
                                      
            foreach ($hostPool in $hostPools)
            {
                $resourceGroupName = ($hostPool.Id).split('/')[4]
                $hostPoolName = $hostPool.Name
                $hostPoolLocation = $hostPool.Location

                $registrationToken = New-AzWvdRegistrationInfo -ResourceGroupName $resourceGroupName -HostPoolName $hostPoolName -ExpirationTime $((get-date).ToUniversalTime().AddDays(7).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
                
                if (!$registrationToken)
                {
                    $registrationToken = Get-AzWvdRegistrationInfo -ResourceGroupName $resourceGroupName -HostPoolName $hostPoolNamee
                }
            
                $obj = $registrationToken | Out-String
                                    
                $result = New-Object -Type PSObject -Property @{
                    "Host pool name" = $hostPool.Name
                    "Resource group name" = ($hostPool.Id).split('/')[4]
                    "Location" = $hostPool.Location
                    "Registration token" = $obj
                }

                $result += $result

                New-AzAutomationVariable -AutomationAccountName $AutomationAccountName -Name $hostPoolName-token -Encrypted $False -Value $obj -ResourceGroupName $ResourceGroupName

                Write-Output -Message "Saved registration token into the automation variable $WVDHostPoolName-token: $obj"
            }
        }
        else
        {
            Write-Output "No host pool found."
        }
    }

    $result | Format-Table -AutoSize
}
catch
{
    Write-Error -Message $_.Exception
    throw $_.Exception    
}
## End of getting all host pools