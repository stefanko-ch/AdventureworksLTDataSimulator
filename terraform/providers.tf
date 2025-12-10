provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "azuread" {
  tenant_id = data.azurerm_client_config.current.tenant_id
}

# MSSQL Provider (betr-io/mssql) - connection details are configured in resources
# See sql_setup.tf for usage

data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}
