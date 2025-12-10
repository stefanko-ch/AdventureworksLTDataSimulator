# ==============================================================================
# Azure SQL Server
# ==============================================================================

resource "azurerm_mssql_server" "main" {
  name                          = lower(replace(var.sql_server_name, "_", "-"))
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "12.0"
  administrator_login           = "sqladmin"
  administrator_login_password  = random_password.sql_admin_password.result
  minimum_tls_version           = "1.2"
  public_network_access_enabled = true

  tags = local.common_tags
}

# Random password for SQL admin
resource "random_password" "sql_admin_password" {
  length  = 32
  special = true
}

# ==============================================================================
# AdventureWorksLT-Live Database
# ==============================================================================

resource "azurerm_mssql_database" "adventureworks_live" {
  name                        = "AdventureWorksLT-Live"
  server_id                   = azurerm_mssql_server.main.id
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  license_type                = "LicenseIncluded"
  sku_name                    = "Basic"    # ~$5/month
  max_size_gb                 = 2
  zone_redundant              = false
  sample_name                 = "AdventureWorksLT"  # Install sample data automatically

  tags = merge(local.common_tags, {
    Purpose = "Live data simulation for CDC/streaming exercises"
  })
}

# ==============================================================================
# SQL Server Firewall Rules
# ==============================================================================

# Allow all IP addresses (for demo purposes - restrict in production!)
resource "azurerm_mssql_firewall_rule" "allow_all" {
  name             = "AllowAll"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# Allow Azure services
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# ==============================================================================
# SQL User Passwords
# ==============================================================================

# Password for writer user (used by Logic Apps for simulation)
resource "random_password" "writer_password" {
  length  = 20
  special = false  # Avoid special chars for easier connection string handling
  upper   = true
  lower   = true
  numeric = true
}

# Password for reader user (for external applications like Databricks)
resource "random_password" "reader_password" {
  length  = 20
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# ==============================================================================
# Store Credentials in Key Vault
# ==============================================================================

# SQL Admin credentials
resource "azurerm_key_vault_secret" "sql_admin_username" {
  name         = "sql-admin-username"
  value        = azurerm_mssql_server.main.administrator_login
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_admin]
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin_password.result
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_admin]
}

# Writer user credentials (for Logic Apps simulation)
resource "azurerm_key_vault_secret" "writer_username" {
  name         = "sql-writer-username"
  value        = "dbwriter"
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_admin]
}

resource "azurerm_key_vault_secret" "writer_password" {
  name         = "sql-writer-password"
  value        = random_password.writer_password.result
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_admin]
}

# Reader user credentials (for external read access)
resource "azurerm_key_vault_secret" "reader_username" {
  name         = "sql-reader-username"
  value        = "dbreader"
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_admin]
}

resource "azurerm_key_vault_secret" "reader_password" {
  name         = "sql-reader-password"
  value        = random_password.reader_password.result
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_admin]
}

# Connection strings
resource "azurerm_key_vault_secret" "connection_string_writer" {
  name         = "sql-connection-string-writer"
  value        = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Initial Catalog=AdventureWorksLT-Live;Persist Security Info=False;User ID=dbwriter;Password=${random_password.writer_password.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_admin]
}

resource "azurerm_key_vault_secret" "connection_string_reader" {
  name         = "sql-connection-string-reader"
  value        = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Initial Catalog=AdventureWorksLT-Live;Persist Security Info=False;User ID=dbreader;Password=${random_password.reader_password.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_admin]
}
