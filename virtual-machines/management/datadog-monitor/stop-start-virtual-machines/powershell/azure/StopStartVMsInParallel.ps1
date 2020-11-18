Workflow StopStartVMsInParallel
{
    param (

        [Parameter(Mandatory=$true)]  
        [String] $Action
    ) 

    ## Authentication
    Write-Output ""
    Write-Output "------------------------ Authentication ------------------------"
    Write-Output "Logging into Azure ..."

    $ConnectionAssetName = "AzureClassicRunAsConnection"       

    # Authenticate to Azure with certificate
    Write-Verbose "Getting connection asset: $ConnectionAssetName" -Verbose

    $Conn = Get-AutomationConnection -Name $ConnectionAssetName
    if ($null -eq $Conn)
    {
        throw "Could not retrieve connection asset: $ConnectionAssetName. Assure that this asset exists in the Automation account."
    }

    $CertificateAssetName = $Conn.CertificateAssetName
    Write-Verbose "Getting the certificate: $CertificateAssetName" -Verbose
    $AzureCert = Get-AutomationCertificate -Name $CertificateAssetName
    if ($null -eq $AzureCert)
    {
        throw "Could not retrieve certificate asset: $CertificateAssetName. Assure that this asset exists in the Automation account."
    }

    Write-Verbose "Authenticating to Azure with certificate." -Verbose
    Set-AzureSubscription -SubscriptionName $Conn.SubscriptionName -SubscriptionId $Conn.SubscriptionID -Certificate $AzureCert 
    Select-AzureSubscription -SubscriptionId $Conn.SubscriptionID
    Write-Output "Successfully logged into Azure." 

    ## End of authentication

    ## Getting all virtual machines
    Write-Output ""
    Write-Output ""
    Write-Output "---------------------------- Status ----------------------------"
    Write-Output "Getting all classic virtual machines from all cloud services ..."

    try
    {
        $cloudServicesContent = @()
        $classicInstances = Get-AzureVM
                 
        if ($classicinstances)
        {               
            foreach -parallel ($classicInstance in $classicInstances)
            {
                sequence
                {
                    $cloudServiceContent = New-Object -Type PSObject -Property @{
                        "Cloud service name" = $($classicInstance.ServiceName)
                        "Instance name" = $($classicInstance.Name)
                        "Instance type" = "Classic compute"
                        "Instance state" = ([System.Threading.Thread]::CurrentThread.CurrentCulture.TextInfo.ToTitleCase($classicInstance.PowerState))
                    }

                    $Workflow:cloudServicesContent += $cloudServiceContent
                }
            }
        }
        else
        {
        }

        InlineScript
        {
            $Using:cloudServicesContent | Format-Table -AutoSize
        }
    }
    catch
    {
        Write-Error -Message $_.Exception
        throw $_.Exception    
    }
    ## End of getting all classic virtual machines

    $runningClassicInstances = ($cloudServicesContent | Where-Object {$_.("Instance state") -eq "Started" -or $_.("Instance state") -eq "Starting"})
    $deallocatedClassicInstances = ($cloudServicesContent | Where-Object {$_.("Instance state") -eq "Deallocated" -or $_.("Instance state") -eq "Deallocating"})

    ## Updating virtual machines power state
    if (($runningClassicInstances) -and ($Action -eq "Stop"))
    {
        Write-Output "--------------------------- Updating ---------------------------"
        Write-Output "Trying to stop virtual machines ..."

        try
        {
            $updateStatuses = @()

            foreach -parallel ($runningClassicInstance in $runningClassicInstances)
            {
                sequence
                {
                    Write-Output "$($runningClassicInstance.("Instance name")) is shutting down ..."
                
                    $startTime = Get-Date -Format G

                    $null = Stop-AzureVM -ServiceName $($runningClassicInstance.("Cloud service name")) -Name $($runningClassicInstance.("Instance name")) -Force
                    
                    $endTime = Get-Date -Format G

                    $updateStatus = New-Object -Type PSObject -Property @{
                        "Cloud service name" = $($runningClassicInstance.("Cloud service name"))
                        "Instance name" = $($runningClassicInstance.("Instance name"))
                        "Start time" = $startTime
                        "End time" = $endTime
                    }
                
                    $Workflow:updateStatuses += $updateStatus
                }          
            }

            InlineScript
            {
                $Using:updateStatuses | Format-Table -AutoSize
            }
        }
        catch
        {
            Write-Error -Message $_.Exception
            throw $_.Exception    
        }
    }
    elseif (($deallocatedClassicInstances) -and ($Action -eq "Start"))
    {
        Write-Output "--------------------------- Updating ---------------------------"
        Write-Output "Trying to start virtual machines ..."

        try
        {
            foreach -parallel ($deallocatedClassicInstance in $deallocatedClassicInstances)
            {                                    
                sequence
                {
                    Write-Output "$($deallocatedClassicInstance.("Instance name")) is starting ..."

                    $startTime = Get-Date -Format G

                    $null = Start-AzureVM -ServiceName $($deallocatedClassicInstance.("Cloud service name")) -Name $($deallocatedClassicInstance.("Instance name"))

                    $endTime = Get-Date -Format G

                    $updateStatus = New-Object -Type PSObject -Property @{
                        "Resource group name" = $($deallocatedClassicInstance.("Cloud service name"))
                        "Instance name" = $($deallocatedClassicInstance.("Instance name"))
                        "Start time" = $startTime
                        "End time" = $endTime
                    }
                
                    $Workflow:updateStatuses += $updateStatus
                }
            
            }

            InlineScript
            {
                $Using:updateStatuses | Format-Table -AutoSize
            }
        }
        catch
        {
            Write-Error -Message $_.Exception
            throw $_.Exception    
        }
    }
    #### End of updating virtual machines power state
}