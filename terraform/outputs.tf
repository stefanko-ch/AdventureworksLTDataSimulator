# ==============================================================================
# Terraform Outputs
# ==============================================================================

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Name of the AdventureWorksLT database"
  value       = azurerm_mssql_database.adventureworks_live.name
}

output "key_vault_name" {
  description = "Name of the Key Vault containing credentials"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "simulation_status" {
  description = "Current status of the simulation Logic Apps"
  value       = var.simulation_enabled ? "ENABLED" : "DISABLED"
}

# ==============================================================================
# Connection Information (sensitive - retrieve from Key Vault in production)
# ==============================================================================

output "connection_info" {
  description = "Connection information for the database"
  value = {
    server   = azurerm_mssql_server.main.fully_qualified_domain_name
    database = azurerm_mssql_database.adventureworks_live.name
    port     = 1433
  }
}

# ==============================================================================
# Deployment Complete Message
# ==============================================================================

output "deployment_info" {
  description = "Deployment completion information"
  value       = <<-EOT

    ╔══════════════════════════════════════════════════════════════════╗
    ║        AdventureWorksLT Data Simulator - FULLY DEPLOYED!         ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║                                                                  ║
    ║  ✅ SQL Server:     ${azurerm_mssql_server.main.fully_qualified_domain_name}
    ║  ✅ Database:       ${azurerm_mssql_database.adventureworks_live.name}
    ║  ✅ SQL Users:      dbwriter, dbreader (auto-created)            ║
    ║  ✅ Stored Procs:   6 simulation procedures (auto-created)       ║
    ║  ✅ Logic Apps:     5 simulation apps (${var.simulation_enabled ? "ENABLED" : "DISABLED"})
    ║  ✅ Key Vault:      ${azurerm_key_vault.main.name}
    ║                                                                  ║
    ║  No manual SQL setup required - everything is automated!         ║
    ║                                                                  ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║  Get credentials from Key Vault:                                 ║
    ║  az keyvault secret show --vault-name ${azurerm_key_vault.main.name} \
    ║     --name sql-reader-password --query value -o tsv              ║
    ║                                                                  ║
    ║  Test the simulation:                                            ║
    ║  EXEC SalesLT.usp_Sim_GetStatus;                                 ║
    ╚══════════════════════════════════════════════════════════════════╝

  EOT
}
