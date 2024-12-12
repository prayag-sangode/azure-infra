provider "azurerm" {
  features {}

  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

terraform {
  backend "azurerm" {
    resource_group_name   = "juiceshop-rg"             # Replace if needed
    storage_account_name  = "juiceshopstorage"         # Matches var.storage_account_name
    container_name        = "terraform-state"          # Matches var.storage_container_name
    key                   = "terraform.tfstate"        # State file name
  }
}

# Declare input variables for Azure authentication
variable "client_id" {
  description = "Azure Client ID"
  type        = string
}

variable "client_secret" {
  description = "Azure Client Secret"
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}
