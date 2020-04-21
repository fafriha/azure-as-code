################################################### Windows Virtual Desktop ################################################

## This automation account will contain the runbook to enable session hosts autoscalling
resource "azurerm_automation_account" "wvd_scaling_tool" {
  name                  = var.wvd_automation_account_name
  location              = azurerm_resource_group.wvd.location
  resource_group_name   = azurerm_resource_group.wvd.name

  sku_name = "Basic"
}


resource "azurerm_automation_module" "wvd_rds_module" {
  name                    = "Microsoft.RDInfra.RDPowershell"
  resource_group_name     = azurerm_resource_group.wvd.name
  automation_account_name = azurerm_automation_account.wvd_scaling_tool.name  

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Microsoft.RDInfra.RDPowershell"
  }
}

resource "azurerm_automation_module" "wvd_accounts_module" {
  name                    = "Az.Accounts"
  resource_group_name     = azurerm_resource_group.wvd.name
  automation_account_name = azurerm_automation_account.wvd_scaling_tool.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts"
  }
}

resource "azurerm_automation_module" "wvd_oms_module" {
  name                    = "OMSIngestionAPI"
  resource_group_name     = azurerm_resource_group.wvd.name
  automation_account_name = azurerm_automation_account.wvd_scaling_tool.name 

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/OMSIngestionAPI"
  }
}

resource "azurerm_automation_module" "wvd_resources_module" {
  name                    = "Az.Resources"
  resource_group_name     = azurerm_resource_group.wvd.name
  automation_account_name = azurerm_automation_account.wvd_scaling_tool.name
  depends_on              = [azurerm_automation_module.wvd_accounts_module]   

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Resources"
  }
}

resource "azurerm_automation_module" "wvd_compute_module" {
  name                    = "Az.Compute"
  resource_group_name     = azurerm_resource_group.wvd.name
  automation_account_name = azurerm_automation_account.wvd_scaling_tool.name
  depends_on              = [azurerm_automation_module.wvd_accounts_module]

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Compute"
  }
}

resource "azurerm_automation_module" "wvd_automation_module" {
  name                    = "Az.Automation"
  resource_group_name     = azurerm_resource_group.wvd.name
  automation_account_name = azurerm_automation_account.wvd_scaling_tool.name
  depends_on              = [azurerm_automation_module.wvd_accounts_module]  

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Automation"
  }
}

# ## This runbook will scale session hosts automatically
# resource "azurerm_automation_runbook" "wvd_scaling_tool" {
#   name                    = "ScaleSessionHosts"
#   location                = azurerm_resource_group.wvd.location
#   resource_group_name     = azurerm_resource_group.wvd.name
#   automation_account_name = azurerm_automation_account.wvd_scaling_tool.name
#   log_verbose             = "true"
#   log_progress            = "true"
#   runbook_type            = "PowerShell"
#   description             = "Part of the scaling tool for Windows Virtual Desktop session hosts."

#   publish_content_link {
#     uri = "https://raw.githubusercontent.com/faroukfriha/azure-as-code/master/Windows%20Virtual%20Desktop/PowerShell/ScaleSessionHosts.ps1"
#   }
# }

resource "null_resource" "wvd_scaling_tool" {
  provisioner "local-exec" {
    command = <<EOT
      Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/faroukfriha/azure-as-code/master/Windows%20Virtual%20Desktop/PowerShell/SetAutomationAccount.ps1' -OutFile 'C:\\Temp\\SetAutomationAccount.ps1';
      Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/faroukfriha/azure-as-code/master/Windows%20Virtual%20Desktop/PowerShell/ScaleSessionHosts.ps1' -OutFile 'C:\\Temp\\ScaleSessionHosts.ps1';
      & 'C:\\Temp\\SetAutomationAccount.ps1' -SubscriptionId ${var.global_subscription_id} -ResourceGroupName ${azurerm_resource_group.wvd.name} -AutomationAccountName ${azurerm_automation_account.wvd_scaling_tool.name} -Location ${azurerm_resource_group.wvd.location} -WorkspaceName ${azurerm_log_analytics_workspace.wvd_monitoring.name} -SelfSignedCertPlainPassword "P@ssw0rd1!" -AADTenantId ${var.global_aad_tenant_id} -SvcPrincipalApplicationId ${azurerm_key_vault_secret.global_terraform_app.name} -SvcPrincipalSecret ${azurerm_key_vault_secret.global_terraform_app.value}

    EOT

    interpreter = ["PowerShell", "-Command"]
  }
}

## This logic app will trigger the runbook created above
resource "azurerm_logic_app_workflow" "wvd_scaling_tool" {
  name                  = var.wvd_logic_app_workflow_name
  location              = azurerm_resource_group.wvd.location
  resource_group_name   = azurerm_resource_group.wvd.name
  depends_on            = [null_resource.wvd_scaling_tool]
}

## This trigger will start the custom action to run the runbook created above
resource "azurerm_logic_app_trigger_recurrence" "wvd_scaling_tool" {
  name         = "Reccurence"
  logic_app_id = azurerm_logic_app_workflow.wvd_scaling_tool.id
  frequency    = "Minute"
  interval     = var.wvd_logic_app_trigger_recurrence
  depends_on   = [null_resource.wvd_scaling_tool]
}

## This action will call a webhook to run the runbook created above
resource "azurerm_logic_app_action_custom" "wvd_scaling_tool" {
  name         = "HTTP Webhook"
  logic_app_id = azurerm_logic_app_workflow.wvd_scaling_tool.id
  depends_on   = [null_resource.wvd_scaling_tool]

  body = <<BODY
{
  "inputs": {
      "subscribe": {
          "body": {
              "AADTenantId": "${var.global_aad_tenant_id}",
              "AutomationAccountName": "${azurerm_automation_account.wvd_scaling_tool.name}",
              "BeginPeakTime": "${var.wvd_begin_peak_time}",
              "ConnectionAssetName": "AzureRunAsConnection",
              "EndPeakTime": "${var.wvd_end_peak_time}",
              "HostPoolName": "${var.wvd_host_pool_name}",
              "LimitSecondsToForceLogOffUser": "${var.wvd_time_before_logoff}",
              "LogAnalyticsPrimaryKey": "${azurerm_log_analytics_workspace.wvd_monitoring.primary_shared_key}",
              "LogAnalyticsWorkspaceId": "${azurerm_log_analytics_workspace.wvd_monitoring.workspace_id}",
              "LogOffMessageBody": "${var.wvd_logoff_message_body}",
              "LogOffMessageTitle": "${var.wvd_logoff_message_title}",
              "MaintenanceTagName": "${var.wvd_maintenance_tag_name}",
              "MinimumNumberOfRDSH": "${var.wvd_minimum_session_host}",
              "RDBrokerURL": "https://rdbroker.wvd.microsoft.com",
              "SessionThresholdPerCPU": "${var.wvd_max_session_per_cpu}",
              "TenantGroupName": "${var.wvd_tenant_group_name}",
              "TenantName": "${var.wvd_tenant_name}",
              "TimeDifference": "${var.wvd_time_difference}",
              "subscriptionid": "${var.global_subscription_id}"
          },
          "method": "POST",
          "uri": "${data.azurerm_automation_variable_string.wvd_scaling_tool.value}"
      },
      "unsubscribe": {}
  },
  "runAfter": {},
  "type": "HttpWebhook"
}
BODY
}