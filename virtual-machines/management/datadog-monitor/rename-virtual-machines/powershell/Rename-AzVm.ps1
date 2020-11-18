#---------------------------------------------------------[Parameters]--------------------------------------------------------

[CmdletBinding()]

Param (
    [string]$SubId = $(throw "-SubId is required."),
    [String]$ResourceGroupName = $(throw "-ResourceGroupName is required."),
    [String]$CurrentVMName = $(throw "-CurrentVMName is required."),
    [String]$NewVMName = $(throw "-NewVMName is required.")
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "Continue"

#-----------------------------------------------------------[Functions]------------------------------------------------------------
  
## Authentication 
# try 
# { 
#     Write-Output "" 
#     Write-Output "Logging in to Azure ..." 
 
#     $Conn = Get-AutomationConnection -Name AzureRunAsConnection 
 
#     # Ensures you do not inherit an AzContext in your runbook 
#     $null = Disable-AzContextAutosave -Scope Process 
     
#     $null = Connect-AzAccount `
#       -ServicePrincipal `
#       -Tenant $Conn.TenantID `
#       -ApplicationId $Conn.ApplicationID `
#       -CertificateThumbprint $Conn.CertificateThumbprint 
 
#     Write-Output "... successfully logged in to Azure."  
# }  
# catch 
# { 
#     if (!$Conn) 
#     { 
#         $ErrorMessage = "... service principal not found." 
#         throw $ErrorMessage 
#     }  
#     else 
#     { 
#         Write-Error -Message "... " + $_.Exception 
#         throw $_.Exception 
#     } 
# } 
# ## End of authentication  

## Gather all properties
Try
{
  ## Get the virtual machine object
  Write-Output "Gathering $CurrentVMName properties ..."

  $currentVMPowerState = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $CurrentVMName -Status).Statuses[1].Code.Split("/")[-1]
  $currentVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $CurrentVMName

  ## Get and set the virtual machine size
  $vmSize = $currentVM.HardwareProfile.VmSize
  Write-Output "... found $vmSize as virtual machine size"

  ## Get and set the virtual machine location
  $location = $currentVM.Location
  Write-Output "... found $location as virtual machine location"

  ## Get the OS disk Id
  $osDiskId = $currentVM.StorageProfile.OsDisk.ManagedDisk.Id
  Write-Output "... found $($osDiskId.Split("/")[-1]) as OS disk"

  ## Get the OS type
  $osDiskType = $currentVM.StorageProfile.OsDisk.OsType
  Write-Output "... found $OsDiskType as OS type"

  ## Get network interface(s)
  $nics = @()
  $nics = $currentVM.NetworkProfile.NetworkInterfaces    
  Write-Output "... found $($nics.count) network interface(s)"

  ## Get and set availability zones
  if ($currentVM.Zones)
  {
    $zone = $currentVM.Zones
    Write-Output "... found $zone as availability zone"
    $newVM = New-AzVMConfig -VMName $NewVMName -VMSize $vmSize -Zone $zone
  }
  else 
  {
    Write-Output "... found no availability zone"
    $newVM = New-AzVMConfig -VMName $NewVMName -VMSize $vmSize
  }

  ## Get data disks
  $dataDisks = @()
  if ($currentVM.StorageProfile.DataDisks)
  {
    $dataDisks = $currentVM.StorageProfile.DataDisks 
    Write-Output "... found $($dataDisks.count) data disk(s)"

    foreach ($dataDisk in $DataDisks)
    {
      Add-AzVMDataDisk `
      -VM $newVM `
      -Name $dataDisk.Name `
      -ManagedDiskId $dataDisk.ManagedDisk.Id `
      -Caching $dataDisk.Caching `
      -Lun $dataDisk.Lun `
      -DiskSizeInGB $dataDisk.DiskSizeGB `
      -CreateOption Attach
    }
  }
  else 
  {
    Write-Output "... found 0 data disk"
  }

  ## Set network interface(s)
  foreach ($nic in $nics) 
  {
    if ($nic.Primary -eq "True")
    {
      Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id -Primary 
    }
    else
    {
      Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id
    }
  } 

  ## Get availability sets
  ## Get extensions
  ## Get unmanaged disks

  ## Get hybrid benefit configuration and set OS disk type
  switch ($osDiskType)
  {
      "Windows" 
      {
        Set-AzVMOSDisk -VM $newVM -ManagedDiskId $osDiskId -CreateOption Attach -Windows

        if ($currentVM.LicenseType)
        {
          $licensing = $currentVM.LicenseType
          Write-Output "... found $licensing as license type"
        }
        else 
        {
          $licensing = "None"
          Write-Output "... found no license type"
        }

        $NewAzVM = 'New-AzVM `
          -ResourceGroupName $ResourceGroupName `
          -Location $location `
          -VM $newVM `
          -LicenseType $licensing `
          -DisableBginfoExtension `
          -Verbose'
      }

      "Linux"  
      {
        Set-AzVMOSDisk -VM $newVM -ManagedDiskId $osDiskId -CreateOption Attach -Linux

        $NewAzVM = 'New-AzVM `
          -ResourceGroupName $ResourceGroupName `
          -Location $location `
          -VM $newVM `
          -Verbose'
      }
  }

  $currentVMProperties = New-Object -Type PSObject -Property @{
      "Resource group name" = $ResourceGroupName
      "Instance name" = $CurrentVMName
      "Instance state" = ([System.Threading.Thread]::CurrentThread.CurrentCulture.TextInfo.ToTitleCase($CurrentVMPowerState))
      "Size" = $vmSize
      "Location" = $location
      "Operating system" = $osDiskType
      "Network interface" = $nics.Count
      "Zone" = $zone
      "Data disk" = $dataDisks.Count
  }

  $currentVMProperties
}
Catch
{
  if ($currentVMPowerState -ne "PowerState/running")
  {
    Write-Output "The virtual machine is not running"
  }
  else 
  {
    Write-Output "Unable to gather all properties : $_"
  }
  Break
}

## Rename virtual machine
Try
{
  ## Disabling boot diagnostics
  $newVM | Set-AzVMBootDiagnostics -Disable

  ## Renaming virtual machine 
  Write-Output "Renaming virtual machine..."

  ## Removing current virtual machine
  Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $CurrentVMName -Force

  ## Creating new virtual machine
  Invoke-Expression $NewAzVM
}
Catch
{
  Write-Output "Unable to rename the virtual machine : $_"
  Break
}