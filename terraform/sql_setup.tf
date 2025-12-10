# ==============================================================================
# Automatic SQL Setup using MSSQL Provider
# ==============================================================================
# This file creates SQL users and stored procedures automatically during
# Terraform deployment - no manual SQL execution needed!
# ==============================================================================

# ==============================================================================
# SQL Users
# ==============================================================================

# Writer User (for Logic Apps simulation)
resource "mssql_user" "writer" {
  server {
    host = azurerm_mssql_server.main.fully_qualified_domain_name
    port = 1433
    login {
      username = azurerm_mssql_server.main.administrator_login
      password = random_password.sql_admin_password.result
    }
  }
  
  database  = azurerm_mssql_database.adventureworks_live.name
  username  = "dbwriter"
  password  = random_password.writer_password.result
  roles     = ["db_datareader", "db_datawriter"]

  depends_on = [
    azurerm_mssql_database.adventureworks_live,
    azurerm_mssql_firewall_rule.allow_all
  ]
}

# Reader User (for external applications like Databricks)
resource "mssql_user" "reader" {
  server {
    host = azurerm_mssql_server.main.fully_qualified_domain_name
    port = 1433
    login {
      username = azurerm_mssql_server.main.administrator_login
      password = random_password.sql_admin_password.result
    }
  }
  
  database  = azurerm_mssql_database.adventureworks_live.name
  username  = "dbreader"
  password  = random_password.reader_password.result
  roles     = ["db_datareader"]

  depends_on = [
    azurerm_mssql_database.adventureworks_live,
    azurerm_mssql_firewall_rule.allow_all
  ]
}

# ==============================================================================
# SQL Scripts Execution via null_resource
# ==============================================================================
# The betr-io/mssql provider only supports user management.
# We use null_resource with local-exec to run SQL scripts via sqlcmd.
# ==============================================================================

resource "null_resource" "sql_procedures" {
  triggers = {
    server_id    = azurerm_mssql_server.main.id
    database_id  = azurerm_mssql_database.adventureworks_live.id
    script_hash  = filemd5("${path.module}/sql_simulation_procedures.sql")
  }

  # Execute stored procedures script
  provisioner "local-exec" {
    command = <<-EOT
      sqlcmd -S ${azurerm_mssql_server.main.fully_qualified_domain_name} \
             -d ${azurerm_mssql_database.adventureworks_live.name} \
             -U ${azurerm_mssql_server.main.administrator_login} \
             -P '${random_password.sql_admin_password.result}' \
             -i ${path.module}/sql_simulation_procedures.sql
    EOT
  }

  # Grant EXECUTE permission to dbwriter
  provisioner "local-exec" {
    command = <<-EOT
      sqlcmd -S ${azurerm_mssql_server.main.fully_qualified_domain_name} \
             -d ${azurerm_mssql_database.adventureworks_live.name} \
             -U ${azurerm_mssql_server.main.administrator_login} \
             -P '${random_password.sql_admin_password.result}' \
             -Q "GRANT EXECUTE ON SCHEMA::SalesLT TO [dbwriter]"
    EOT
  }

  depends_on = [
    mssql_user.writer,
    mssql_user.reader,
    azurerm_mssql_firewall_rule.allow_all
  ]
}
