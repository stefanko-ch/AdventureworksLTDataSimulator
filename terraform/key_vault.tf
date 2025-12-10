# ==============================================================================
# Key Vault for storing SQL credentials securely
# ==============================================================================

resource "azurerm_key_vault" "main" {
  name                = lower(replace(var.key_vault_name, "_", "-"))
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enabled_for_deployment          = false
  enabled_for_template_deployment = false
  enabled_for_disk_encryption     = false

  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  enable_rbac_authorization  = true

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = local.common_tags
}

# RBAC: Key Vault Secrets Officer for admin user (Terraform operator)
resource "azurerm_role_assignment" "kv_secrets_officer_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azuread_user.admin.object_id
}

# Data source to get admin user
data "azuread_user" "admin" {
  user_principal_name = var.admin_email
}
