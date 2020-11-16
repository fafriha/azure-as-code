
# Azure as Code

![Maintenance](https://img.shields.io/maintenance/yes/2020?style=for-the-badge&logo=awesome-lists&logoColor=white)
![GitHub followers](https://img.shields.io/github/followers/faroukfriha?style=for-the-badge&logo=github)
![Forks](https://img.shields.io/github/forks/faroukfriha/azure-as-code?style=for-the-badge&logo=github)
![Commits](https://img.shields.io/github/commit-activity/m/faroukfriha/azure-as-code?style=for-the-badge&logo=github)
![Last commit](https://img.shields.io/github/last-commit/faroukfriha/azure-as-code?style=for-the-badge&logo=github)

## Description
Let people know what your project can do specifically. Provide context and add a link to any reference visitors might be unfamiliar with. A list of Features or a Background subsection can also be added here. If there are alternatives to your project, this is a good place to list differentiating factors.

## Table of contents

- [Windows Virtual Desktop](#windows-virtual-desktop)
- [Azure Kubernetes Services](#azure-kubernetes-services)
- [Virtual Machines Management](#virtual-machines-management)
  - [Monitor](#monitor)
    - [Datadog](#datadog)
    - [Dynatrace](#dynatrace)
    - [Azure Monitor](#azure-monitor)
  - [Storage](#storage)
      - [Mount disks on virtual machine creation](#mount-disks-on-virtual-machine-creation)
  - [Metadata](#metadata)
    - [Rename virtual machines](#rename-virtual-machines)
  - [Cost](#cost)
    - [Stop or start virtual machines](#stopstartvms)
    - [StopStartClassicVMs](#stopstartclassicvms)
- [Azure Active Directory](#azure-active-directory)
  - [Sort applications](#sort-applications)
- [Dev/Test Labs](#dev/test-labs)


## Windows Virtual Destkop
![Windows Virtual Desktop](https://img.shields.io/github/workflow/status/faroukfriha/azure-as-code/Windows%20Virtual%20Desktop/master?logo=github-actions&logoColor=white&style=for-the-badge)

## Azure Kubernetes Services

Coming soon

## Azure Active Directory
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

## Contribution

Contributions are **greatly appreciated**. For major changes, please open an issue first to discuss what you would like to change or work in your forked repository and send me a pull request as described below.

1. Fork the current project
    `git clone https://github.com/faroukfriha/azure-as-code`
2. Create your feature branch as the following
    `git checkout -b feature-<oneoftherootfoldername>-<yourawesomefeaturename>`
3. Commit your changes
    `git commit -m 'Adding an awesome feature'`
4. Push your commit to the branch
    `git push origin feature-<oneoftherootfoldername>-<yourawesomefeaturename>`
5. Click [New pull request](https://github.com/faroukfriha/azure-as-code/compare) to open a new pull request


## Languages

All the projects included in this repository have been built with the following tools and languages.

![Terraform](https://img.shields.io/badge/terraform-%23623CE4.svg?&style=for-the-badge&logo=terraform&logoColor=white) 
![PowerShell](https://img.shields.io/badge/powershell-%235391FE.svg?&style=for-the-badge&logo=powershell&logoColor=white) 
![Python](https://img.shields.io/badge/python-%233776AB.svg?&style=for-the-badge&logo=python&logoColor=white)
![Chocolatey](https://img.shields.io/badge/chocolatey-%2380B5E3.svg?&style=for-the-badge&logo=chocolatey&logoColor=white)
![JSON](https://img.shields.io/badge/json-%23000000.svg?&style=for-the-badge&logo=json) 

## Author
[![Linkedin](https://img.shields.io/badge/linkedin-%230077B5.svg?&style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/faroukfriha) 
[![Twitter](https://img.shields.io/badge/twitter-%231DA1F2.svg?&style=for-the-badge&logo=twitter&logoColor=white)](https://www.twitter.com/faroukfriha) 
[![GitHub](https://img.shields.io/badge/github-%23181717.svg?&style=for-the-badge&logo=github)](https://www.github.com/faroukfriha)

## License
Distributed under the [![License](https://img.shields.io/badge/MIT-%233DA639.svg?&style=for-the-badge&logoColor=white&logo=open-source-initiative&color=black)](https://opensource.org/licenses/MIT) license.