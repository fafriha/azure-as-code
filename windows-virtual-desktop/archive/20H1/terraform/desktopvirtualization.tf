# ## This workspace will be used to group all app groups
# resource "azurerm_template_deployment" "wvd_workspace" {
#   count               = var.create_workspace ? 1 : 0
#   name                = "wvd-workspace"
#   resource_group_name = azurerm_resource_group.wvd.name

#   template_body = <<DEPLOY
# {
#     "$schema": "http://schema.management.azure.com/schemas/2014-04-01-preview/deploymentTemplate.json#",
#     "contentVersion": "1.0.0.0",
#     "parameters": {
#         "workspaceName": {
#             "type": "string"
#         },
#         "workspaceDescription": {
#             "type": "string",
#             "defaultValue": ""
#         },
#         "location": {
#             "type": "string",
#             "defaultValue": ""
#         },
#         "friendlyName": {
#             "type": "string",
#             "defaultValue": ""
#         },
#         "appGroups": {
#             "type": "array",
#             "defaultValue": []
#         }
#     },
#     "resources": [
#         {
#             "name": "[parameters('workspaceName')]",
#             "apiVersion": "2019-12-10-preview",
#             "type": "Microsoft.DesktopVirtualization/workspaces",
#             "location": "[parameters('location')]",
#             "properties": {
#                 "friendlyName": "[parameters('workspaceName')]",
#                 "description": "[parameters('workspaceDescription')]",
#                 "applicationGroupReferences": "[parameters('appGroups')]"
#             }
#         }
#     ]
# }
# DEPLOY

#   parameters = {
#     "workspaceName" = var.wvd_worskpace_name
#     "location"      = var.wvd_metadata_location
#     "friendlyName"  = var.wvd_workspace_friendly_name
#     "description"   = var.wvd_workspace_description
#     "appGroups"     = ["/subscriptions/SUBID/resourcegroups/RGNAME/providers/Microsoft.DesktopVirtualization/applicationgroups/APPGROUPNAME"
#   }

#   deployment_mode = "Incremental"
# }

# ## Create hostpool without session hosts
# resource "azurerm_template_deployment" "wvd_hostpool" {
#   count               = var.create_hostpool ? 1 : 0
#   name                = "wvd-hostpool"
#   resource_group_name = azurerm_resource_group.wvd.name

#   template_body = <<DEPLOY
# {
#     "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
#     "contentVersion": "1.0.0.0",
#     "parameters": {
#         "hostpoolType": {
#             "type": "SecureString"
#         },
#         "desktopAssignmentType": {
#             "type": "SecureString"
#         },
#         "maxSessionLimit": {
#             "type": "SecureString"
#         },
#         "hostpoolName": {
#             "type": "String"
#         },
#         "desktopAssignementType": {
#             "type": "String"
#         }
#     },
#     "resources": [
#         {
#             "type": "Microsoft.DesktopVirtualization/hostpools",
#             "apiVersion": "2019-12-10-preview",
#             "name": "[parameters('hostpoolName')]",
#             "location": "[parameters('location')]",
#             "properties": {
#                 "hostPoolType": "[parameters('hostpoolType')]",
#                 "maxSessionLimit": "[parameters('maxSessionLimit')]",
#                 "loadBalancerType": "[parameters('loadbalancerType')]",
#                 "validationEnvironment": [parameters('validationEnvironment')],
#                 "personalDesktopAssignmentType": "[parameters('desktopAssignementType')]"
#             }
#         }
#     ]
# }
# DEPLOY

#   parameters = {
#     "hostpoolType"           = var.wvd_worskpace_name
#     "location"               = var.wvd_metada_location
#     "maxSessionLimit"        = var.wvd_max_session_limit
#     "loadBalancerType"       = var.wvd_loadbalancer_type
#     "validationEnvironment"  = var.wvd_validation_environment
#     "desktopAssignmentType"  = var.wvd_desktop_assignement_type
#   }

#   deployment_mode = "Incremental"
# }

# ## Create application group
# resource "azurerm_template_deployment" "wvd_appgroup" {
#   count               = var.create_appgroup ? 1 : 0
#   name                = "wvd-appgroup"
#   resource_group_name = azurerm_resource_group.wvd.name

#   template_body = <<DEPLOY
# {
#     "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
#     "contentVersion": "1.0.0.0",
#     "parameters": {
#         "applicationgroupName": {
#             "type": "String"
#         },
#         "hostpoolId": {
#             "type": "String"
#         }
#     },
#     "resources": [
#         {
#             "type": "Microsoft.DesktopVirtualization/applicationgroups",
#             "apiVersion": "2019-12-10-preview",
#             "name": "[parameters('applicationgroupName')]",
#             "location": "[parameters('location')]",
#             "kind": "Desktop",
#             "properties": {
#                 "hostPoolArmPath": "[parameters('hostpoolId')]",
#                 "friendlyName": "Default Desktop",
#                 "applicationGroupType": "Desktop"
#             }
#         }
#     ]
# }
# DEPLOY

#   parameters = {
#     "hostpoolType"           = var.wvd_worskpace_name
#     "location"               = var.wvd_metada_location
#     "maxSessionLimit"        = var.wvd_max_session_limit
#     "loadBalancerType"       = var.wvd_loadbalancer_type
#     "validationEnvironment"  = var.wvd_validation_environment
#     "desktopAssignmentType"  = var.wvd_desktop_assignement_type
#   }

#   deployment_mode = "Incremental"
# }