################################################### Windows Virtual Desktop ################################################

## This automation account will contain the runbook to enable session hosts autoscalling
resource "azurerm_automation_account" "wvd_scaling_tool" {
  name                  = var.wvd_automation_account_name
  location              = azurerm_resource_group.wvd.location
  resource_group_name   = azurerm_resource_group.wvd.name

  sku_name = "Basic"
}

resource "null_resource" "wvd_scaling_tool" {
  provisioner "local-exec" {
    command = "&{Invoke-WebRequest -Uri $Uri -OutFile; & $OutFile -SubscriptionID $SubscriptionId -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Location $Location	-WorkspaceName $WorkspaceName	-SelfSignedCertPlainPassword $SelfSignedCertPlainPassword -RunbookName $RunbookName -WebhookName $WebhookName -AADTenantId $AADTenantId -SvcPrincipalApplicationId $SvcPrincipalApplicationId -SvcPrincipalSecret $SvcPrincipalSecret}"

    environment = {
      OutFile = "C:\\temp\\SetAutomationAccount.ps1"
      Uri = "https://raw.githubusercontent.com/faroukfriha/azure-as-code/master/Windows%20Virtual%20Desktop/PowerShell/SetAutomationAccount.ps1"
      SubscriptionId = var.global_subscription_id
      ResourceGroupName = azurerm_resource_group.wvd.name
      AutomationAccountName = azurerm_automation_account.wvd_scaling_tool.name
      Location = azurerm_resource_group.wvd.location
      WorkspaceName = azurerm_log_analytics_workspace.wvd_monitoring.name
      #SelfSignedCertPlainPassword = azurerm_key_vault_secret.automation_run_as_account_cert_pwd.value
      SelfSignedCertPlainPassword = "P@ssw0rd1!"
      RunbookName = azurerm_automation_runbook.wvd_scaling_tool.name
      WebhookName = var.wvd_webhook_name
      AADTenantId = var.global_aad_tenant_id
      SvcPrincipalApplicationId = azurerm_key_vault_secret.global_terraform_app.name
      SvcPrincipalSecret = azurerm_key_vault_secret.global_terraform_app.value
    }

    interpreter = ["PowerShell", "-Command"]
  }
}

## This runbook will scale session hosts automatically
resource "azurerm_automation_runbook" "wvd_scaling_tool" {
  name                    = var.wvd_runbook_name
  location                = azurerm_resource_group.wvd.location
  resource_group_name     = azurerm_resource_group.wvd.name
  automation_account_name = azurerm_automation_account.wvd_scaling_tool.name
  log_verbose             = "true"
  log_progress            = "true"
  runbook_type            = "PowerShell"

  publish_content_link {
    uri = "https://raw.githubusercontent.com/faroukfriha/azure-as-code/master/Windows%20Virtual%20Desktop/PowerShell/ScaleSessionHosts.ps1"
  }
}

## This logic app will trigger the runbook created above
resource "azurerm_logic_app_workflow" "wvd_scaling_tool" {
  name                  = var.wvd_logic_app_workflow_name
  location              = azurerm_resource_group.wvd.location
  resource_group_name   = azurerm_resource_group.wvd.name
}

## This trigger will start the custom action to run the runbook created above
resource "azurerm_logic_app_trigger_recurrence" "wvd_scaling_tool" {
  name         = "Reccurence"
  logic_app_id = azurerm_logic_app_workflow.wvd.id
  frequency    = "Minute"
  interval     = var.wvd_logic_app_trigger_recurrence
}

## This action will call a webhook to run the runbook created above
resource "azurerm_logic_app_action_custom" "wvd_scaling_tool" {
  name         = "HTTP Webhook"
  logic_app_id = azurerm_logic_app_workflow.wvd_scaling_tool.id

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