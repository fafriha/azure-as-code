################################################### Windows Virtual Dsktop ################################################
# Update - Ajout des modules PowerShell nécessaires

## This automation account will contain the runbook to enable session hosts autoscalling
resource "azurerm_automation_account" "wvd" {
  name                  = var.wvd_automation_account_name
  location              = azurerm_resource_group.wvd.location
  resource_group_name   = azurerm_resource_group.wvd.name

  sku_name = "Basic"
}

## This runbook will scale session hosts automatically
resource "azurerm_automation_runbook" "wvd" {
  name                    = var.wvd_runbook_name
  location                = azurerm_resource_group.wvd.location
  resource_group_name     = azurerm_resource_group.wvd.name
  automation_account_name = azurerm_automation_account.wvd.name
  log_verbose             = "true"
  log_progress            = "true"
  runbook_type            = "PowerShell"

  publish_content_link {
    uri = "${var.wvd_base_url}/scaling.ps1"
  }
}

## This logic app will trigger the runbook created above
resource "azurerm_logic_app_workflow" "wvd" {
  name                  = var.wvd_logic_app_workflow_name
  location              = azurerm_resource_group.wvd.location
  resource_group_name   = azurerm_resource_group.wvd.name
}

## This trigger will start the custom action to run the runbook created above
resource "azurerm_logic_app_trigger_recurrence" "wvd" {
  name         = "Reccurence"
  logic_app_id = azurerm_logic_app_workflow.wvd.id
  frequency    = var.wvd_logic_app_trigger_frequency
  interval     = var.wvd_logic_app_trigger_interval
}

## This action will call a webhook to run the runbook created above
resource "azurerm_logic_app_action_custom" "wvd" {
  name         = var.wvd_logic_app_action_name
  logic_app_id = azurerm_logic_app_workflow.wvd.id

  body = <<BODY
{
  "inputs": {
      "subscribe": {
          "body": {
              "AADTenantId": "${var.aad_tenant_id}",
              "AutomationAccountName": "${azurerm_automation_account.wvd.name}",
              "BeginPeakTime": "${var.wvd_begin_peak_time}",
              "ConnectionAssetName": "${var.wvd_connection_asset_name}",
              "EndPeakTime": "${var.wvd_end_peak_time}",
              "HostPoolName": "${var.wvd_host_pool_name}",
              "LimitSecondsToForceLogOffUser": "${var.wvd_time_before_logoff}",
              "LogAnalyticsPrimaryKey": "${azurerm_log_analytics_workspace.wvd.primary_shared_key}",
              "LogAnalyticsWorkspaceId": "${azurerm_log_analytics_workspace.wvd.workspace_id}",
              "LogOffMessageBody": "${var.wvd_logoff_message_body}",
              "LogOffMessageTitle": "${var.wvd_logoff_message_title}",
              "MaintenanceTagName": "${var.wvd_maintenance_tag_name}",
              "MinimumNumberOfRDSH": "${var.wvd_minimum_session_host}",
              "RDBrokerURL": "${var.wvd_rdbroker_url}",
              "SessionThresholdPerCPU": "${var.wvd_max_session_per_cpu}",
              "TenantGroupName": "${var.wvd_tenant_group_name}",
              "TenantName": "${var.wvd_tenant_name}",
              "TimeDifference": "${var.wvd_time_difference}",
              "subscriptionid": "${var.subscription_id}"
          },
          "method": "POST",
          "uri": "${local.webhook}"
      },
      "unsubscribe": {}
  },
  "runAfter": {},
  "type": "HttpWebhook"
}
BODY

  depends_on = [azurerm_template_deployment.wvd]
}

## This random string will be the token used to generate a webhook uri 
resource "random_string" "wvd_token" {
  length  = 43
  upper   = true
  lower   = true
  number  = true
  special = false
}

## This is the webhook runbook that will be associated to the runbook created above
locals {
  webhook = "https://s18events.azure-automation.net/webhooks?token=${random_string.wvd_token.result}%3d"
}

## This ARM template will assign the webhook to the runbook
resource "azurerm_template_deployment" "wvd" {
  name                = var.wvd_template_name
  resource_group_name = azurerm_resource_group.wvd.name
  deployment_mode     = "Incremental"
  template_body = <<DEPLOY
{
  "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": [
    {
      "name": "${azurerm_automation_account.wvd.name}/${var.wvd_webhook_name}",
      "type": "Microsoft.Automation/automationAccounts/webhooks",
      "apiVersion": "2015-10-31",
      "properties": {
        "isEnabled": true,
        "uri": "${local.webhook}",
        "expiryTime": "2028-01-01T00:00:00.000+00:00",
        "parameters": {},
        "runbook": {
          "name": "${azurerm_automation_runbook.wvd.name}"
        }
      }
    }
  ]
}
DEPLOY
}