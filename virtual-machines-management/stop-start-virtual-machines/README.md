# Virtual Machines Management

These following runbooks will help you managed all of your resources in your Azure subscriptions.

## StopStartVMs

### Description

This PowerShell Workflow Runbook connects to Azure using an Automation Run As account, retrieves the power status of Azure VMs and turns off / on  in parallel those that are turned on / off. You can attach a recurring schedule to this runbook to run it at a specific time.

### Required

1. An Automation connection asset called AzureRunAsConnection that contains the information for connecting with Azure using a service principal.  To use an asset with a different name you can pass the asset name as a input parameter to this runbook.

2. An Action input parameter value that allows the runbook to manage VMs power state. The parameter must be set to "Stop" or "Start".

### Deployment

Copy and paste the content of the script named StopStartVMs.ps1 to your Azure Automation Runbook or integrate this repository to your Azure Automation account as shown [here](https://docs.microsoft.com/en-us/azure/automation/automation-source-control-integration#step-2--set-up-source-control-in-azure-automation).

## StopStartClassicVMs

### Description

This PowerShell Workflow Runbook connects to Azure using an Automation Classic Run As account, retrieves the power status of Azure classic VMs and turns off / on  in parallel those that are turned on / off. You can attach a recurring schedule to this runbook to run it at a specific time.

### Required

1. An Automation connection asset called AzureClassicRunAsConnection that contains the information for connecting with Azure using a service principal.  To use an asset with a different name you can pass the asset name as a input parameter to this runbook.

2. An Action input parameter value that allows the runbook to manage VMs power state. The parameter must be set to "Stop" or "Start".

### Deployment

Copy and paste the content of the script named StopStartClassicVMs.ps1 to your Azure Automation Runbook or integrate this repository to your Azure Automation account as shown [here](https://docs.microsoft.com/en-us/azure/automation/automation-source-control-integration#step-2--set-up-source-control-in-azure-automation).