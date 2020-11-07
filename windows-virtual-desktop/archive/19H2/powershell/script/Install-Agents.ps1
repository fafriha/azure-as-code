#Requires -Version 4.0
#Requires -RunAsAdministrator
<#
.SYNOPSIS
Deploys agent into a virtual machine to promote it as a Windows Virtual Desktop sesion host.

.DESCRIPTION
This script will get the registration token for the target pool name and run all required installer into the target virtual machine.
If the pool name is not specified it will retreive first one (treat this as random) from the deployment.

.PARAMETER RegistrationToken
Required the token of the target host pool

.EXAMPLE
.\Install-Agents.ps1 -RegistrationToken <token>
#>

Param
(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$RegistrationToken
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#Installing FSLogix Apps
Write-Output "Installing FSLogix Apps ...`n"
$fslogix_deploy_status = Start-Process .\FSLogixAppsSetup.exe -ArgumentList "/quiet", "/norestart", "/log C:\Windows\Temp\FSLogixApps.txt" -Wait -PassThru
$sts = $fslogix_deploy_status.ExitCode
Write-Output "Installing FSLogix Apps on virtual machine complete. Exit code=$sts`n"

#Installing RD Agent Boot Loader
Write-Output "Installing RD Agent Boot Loader ...`n"
$bootloader_deploy_status = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i .\WindowsVirtualDesktopAgentBootLoader.msi", "/quiet", "/qn", "/norestart", "/passive", "/l* C:\Windows\Temp\WindowsVirtualDesktopAgentBootLoader.txt" -Wait -Passthru
$sts = $bootloader_deploy_status.ExitCode
Write-Output "Installing RD Agent Boot Loader on virtual machine complete. Exit code=$sts`n"

#install the RD Infra Agent
Write-Output "Installing RD Infra Agent ...`n"
$agent_deploy_status = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i .\WindowsVirtualDesktopAgent.msi", "/quiet", "/qn", "/norestart", "/passive", "REGISTRATIONTOKEN=$RegistrationToken", "/l* C:\Windows\Temp\WindowsVirtualDesktopAgent.txt" -Wait -Passthru
$sts = $agent_deploy_status.ExitCode
Write-Output "Installing RD Infra Agent on virtual machine complete. Exit code=$sts`n"

Write-output "Starting service ..."
Start-Service RDAgentBootLoader

$agent_deploy_status = $agent_deploy_status.ExitCode