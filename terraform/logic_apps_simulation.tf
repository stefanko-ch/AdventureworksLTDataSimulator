# ==============================================================================
# Logic Apps for AdventureWorksLT-Live Data Simulation
# ==============================================================================
# 5 Logic Apps with offset timers to simulate continuous database activity.
# Each runs at the configured interval with a 1-minute offset to spread the load.
#
# Schedule (default 5-minute interval):
#   Minute 0,5,10...: usp_Sim_GenerateNewOrders (100 new orders)
#   Minute 1,6,11...: usp_Sim_ShipPendingOrders (ship ~50% pending)
#   Minute 2,7,12...: usp_Sim_UpdateCustomerInfo (update 20 customers)
#   Minute 3,8,13...: usp_Sim_GenerateNewCustomers (10-20 new customers)
#   Minute 4,9,14...: usp_Sim_CancelRandomOrders (cancel ~10% pending)
#
# Control: Set var.simulation_enabled = false to disable all Logic Apps
# ==============================================================================

# API Connection for Azure SQL (shared by all Logic Apps)
resource "azurerm_resource_group_template_deployment" "sql_connection" {
  name                = "sql-connection-deployment"
  resource_group_name = azurerm_resource_group.main.name
  deployment_mode     = "Incremental"

  template_content = jsonencode({
    "$schema" = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    resources = [
      {
        type       = "Microsoft.Web/connections"
        apiVersion = "2016-06-01"
        name       = "sql-adventureworks-live"
        location   = azurerm_resource_group.main.location
        properties = {
          displayName = "AdventureWorksLT-Live SQL Connection"
          api = {
            id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.main.location}/managedApis/sql"
          }
          parameterValues = {
            server   = azurerm_mssql_server.main.fully_qualified_domain_name
            database = azurerm_mssql_database.adventureworks_live.name
            authType = "basic"
            username = azurerm_key_vault_secret.writer_username.value
            password = random_password.writer_password.result
          }
        }
        tags = local.common_tags
      }
    ]
    outputs = {
      connectionId = {
        type  = "string"
        value = "[resourceId('Microsoft.Web/connections', 'sql-adventureworks-live')]"
      }
    }
  })

  depends_on = [
    azurerm_mssql_database.adventureworks_live
  ]
}

# Local for connection ID
locals {
  sql_connection_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/providers/Microsoft.Web/connections/sql-adventureworks-live"
}

# ==============================================================================
# Logic App Definitions
# ==============================================================================

locals {
  simulation_procedures = {
    "generate-orders" = {
      name          = "logic-sim-generate-orders"
      procedure     = "SalesLT.usp_Sim_GenerateNewOrders"
      offset_minute = 0
      parameters    = { "OrderCount" = 100 }
      description   = "Generate 100 new orders"
    }
    "ship-orders" = {
      name          = "logic-sim-ship-orders"
      procedure     = "SalesLT.usp_Sim_ShipPendingOrders"
      offset_minute = 1
      parameters    = {}
      description   = "Ship ~50% of pending orders"
    }
    "update-customers" = {
      name          = "logic-sim-update-customers"
      procedure     = "SalesLT.usp_Sim_UpdateCustomerInfo"
      offset_minute = 2
      parameters    = { "UpdateCount" = 20 }
      description   = "Update 20 customer records"
    }
    "new-customers" = {
      name          = "logic-sim-new-customers"
      procedure     = "SalesLT.usp_Sim_GenerateNewCustomers"
      offset_minute = 3
      parameters    = { "MinCount" = 10, "MaxCount" = 20 }
      description   = "Generate 10-20 new customers"
    }
    "cancel-orders" = {
      name          = "logic-sim-cancel-orders"
      procedure     = "SalesLT.usp_Sim_CancelRandomOrders"
      offset_minute = 4
      parameters    = {}
      description   = "Cancel ~10% of pending orders"
    }
  }
}

# Deploy all Logic Apps via ARM Template
resource "azurerm_resource_group_template_deployment" "simulation_logic_apps" {
  name                = "simulation-logic-apps-deployment"
  resource_group_name = azurerm_resource_group.main.name
  deployment_mode     = "Incremental"

  template_content = jsonencode({
    "$schema" = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    resources = [
      for key, config in local.simulation_procedures : {
        type       = "Microsoft.Logic/workflows"
        apiVersion = "2019-05-01"
        name       = config.name
        location   = azurerm_resource_group.main.location
        properties = {
          state = var.simulation_enabled ? "Enabled" : "Disabled"
          definition = {
            "$schema" = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
            contentVersion = "1.0.0.0"
            triggers = {
              Recurrence = {
                type = "Recurrence"
                recurrence = {
                  frequency = "Minute"
                  interval  = var.simulation_interval_minutes
                  startTime = "2025-01-01T00:0${config.offset_minute}:00Z"
                  timeZone  = "UTC"
                }
              }
            }
            actions = {
              "Execute_Stored_Procedure" = {
                type = "ApiConnection"
                inputs = {
                  host = {
                    connection = {
                      name = "@parameters('$connections')['sql']['connectionId']"
                    }
                  }
                  method = "post"
                  path   = "/v2/datasets/@{encodeURIComponent(encodeURIComponent('${azurerm_mssql_server.main.fully_qualified_domain_name}'))},@{encodeURIComponent(encodeURIComponent('${azurerm_mssql_database.adventureworks_live.name}'))}/procedures/@{encodeURIComponent(encodeURIComponent('${config.procedure}'))}"
                  body   = length(config.parameters) > 0 ? config.parameters : {}
                }
                runAfter = {}
              }
            }
            parameters = {
              "$connections" = {
                type         = "Object"
                defaultValue = {}
              }
            }
          }
          parameters = {
            "$connections" = {
              value = {
                sql = {
                  connectionId   = local.sql_connection_id
                  connectionName = "sql-adventureworks-live"
                  id             = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.main.location}/managedApis/sql"
                }
              }
            }
          }
        }
        tags = merge(local.common_tags, {
          Purpose     = "Data Simulation"
          Procedure   = config.procedure
          Schedule    = "Every ${var.simulation_interval_minutes} min, offset ${config.offset_minute}"
          Description = config.description
        })
      }
    ]
  })

  depends_on = [
    azurerm_resource_group_template_deployment.sql_connection
  ]
}
