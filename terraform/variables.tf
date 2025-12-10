# ==============================================================================
# Required Variables - Users MUST set these
# ==============================================================================

variable "subscription_id" {
  description = "Azure Subscription ID where resources will be created"
  type        = string
}

variable "admin_email" {
  description = "Email of the admin user who will have full access to all resources"
  type        = string
}

# ==============================================================================
# Optional Variables - Users can customize these
# ==============================================================================

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "North Europe"
}

variable "resource_group_name" {
  description = "Name of the resource group to create"
  type        = string
  default     = "rg-adventureworks-simulator"
}

variable "sql_server_name" {
  description = "Name of the SQL Server (must be globally unique, lowercase, no underscores)"
  type        = string
  default     = "sql-adventureworks-sim"
}

variable "key_vault_name" {
  description = "Name of the Key Vault (must be globally unique, 3-24 chars, alphanumeric and hyphens)"
  type        = string
  default     = "kv-awsim"
}

variable "simulation_enabled" {
  description = "Enable or disable the data simulation Logic Apps. Set to false to stop all simulations."
  type        = bool
  default     = true
}

variable "simulation_interval_minutes" {
  description = "Interval in minutes between simulation runs (each Logic App runs at this interval)"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# Local Values
# ==============================================================================

locals {
  common_tags = merge({
    Project     = "AdventureWorksLT Data Simulator"
    Environment = "Demo"
    ManagedBy   = "Terraform"
  }, var.tags)
}
