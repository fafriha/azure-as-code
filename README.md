
# Azure as Code

![GitHub followers](https://img.shields.io/github/followers/faroukfriha?style=for-the-badge&logo=github)
![Forks](https://img.shields.io/github/forks/faroukfriha/azure-as-code?style=for-the-badge&logo=github)
![Commits](https://img.shields.io/github/commit-activity/w/faroukfriha/azure-as-code?style=for-the-badge&logo=github)
![Last commit](https://img.shields.io/github/last-commit/faroukfriha/azure-as-code?style=for-the-badge)


## Windows Virtual Destkop
![Windows Virtual Desktop](https://github.com/faroukfriha/azure-as-code/workflows/Windows%20Virtual%20Desktop/badge.svg)



## Azure Kubernetes Services

Coming soon

## Azure AD
### Sort applications
Coming soon
## Virtual machines management
The following functions/runbooks/scripts will help you managed all of your resources in your Azure subscriptions.
### Monitor
#### Datadog
Coming soon
#### Dynatrace
Coming soon
#### Azure Monitor
Coming soon
### Storage
#### Mount disks on virtual machine creation
Coming soon
### Metadata
#### Rename virtual machines
Coming soon
### Cost
#### StopStartVMs
##### Description

This PowerShell Workflow Runbook connects to Azure using an Automation Run As account, retrieves the power status of Azure VMs and turns off / on  in parallel those that are turned on / off. You can attach a recurring schedule to this runbook to run it at a specific time.

##### Required

1. An Automation connection asset called AzureRunAsConnection that contains the information for connecting with Azure using a service principal.  To use an asset with a different name you can pass the asset name as a input parameter to this runbook.

2. An Action input parameter value that allows the runbook to manage VMs power state. The parameter must be set to "Stop" or "Start".

##### Deployment

Copy and paste the content of the script named StopStartVMs.ps1 to your Azure Automation Runbook or integrate this repository to your Azure Automation account as shown [here](https://docs.microsoft.com/en-us/azure/automation/automation-source-control-integration#step-2--set-up-source-control-in-azure-automation).

#### StopStartClassicVMs

##### Description

This PowerShell Workflow Runbook connects to Azure using an Automation Classic Run As account, retrieves the power status of Azure classic VMs and turns off / on  in parallel those that are turned on / off. You can attach a recurring schedule to this runbook to run it at a specific time.

##### Required

1. An Automation connection asset called AzureClassicRunAsConnection that contains the information for connecting with Azure using a service principal.  To use an asset with a different name you can pass the asset name as a input parameter to this runbook.

2. An Action input parameter value that allows the runbook to manage VMs power state. The parameter must be set to "Stop" or "Start".

##### Deployment

Copy and paste the content of the script named StopStartClassicVMs.ps1 to your Azure Automation Runbook or integrate this repository to your Azure Automation account as shown [here](https://docs.microsoft.com/en-us/azure/automation/automation-source-control-integration#step-2--set-up-source-control-in-azure-automation).

## Dev/Test Labs
Coming soon

---

## Status

![Maintenance](https://img.shields.io/maintenance/yes/2020?style=flat-square)


## Languages

![Terraform](https://img.shields.io/badge/powershell-%235391FE.svg?&style=for-the-badge&logo=powershell&logoColor=white) ![Terraform](https://img.shields.io/badge/terraform-%23623CE4.svg?&style=for-the-badge&logo=terraform&logoColor=white) ![Terraform](https://img.shields.io/badge/python-%233776AB.svg?&style=for-the-badge&logo=python&logoColor=white)
![Terraform](https://img.shields.io/badge/chocolatey-%2380B5E3.svg?&style=for-the-badge&logo=chocolatey&logoColor=white)
![Terraform](https://img.shields.io/badge/json-%23000000.svg?&style=for-the-badge&logo=json) 

## Author
[![Linkedin](https://img.shields.io/badge/linkedin-%230077B5.svg?&style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/faroukfriha) [![Twitter](https://img.shields.io/badge/twitter-%231DA1F2.svg?&style=for-the-badge&logo=twitter&logoColor=white)](https://www.twitter.com/faroukfriha) [![GitHub](https://img.shields.io/badge/github-%23181717.svg?&style=for-the-badge&logo=github)](https://www.github.com/faroukfriha)

## License
![License](https://img.shields.io/github/license/faroukfriha/azure-as-code?style=for-the-badge&logo=open-source-initiative&logoColor=white) 
