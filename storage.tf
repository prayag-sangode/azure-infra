provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

# Variables for authentication
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "client_id" {
  description = "Azure Client ID"
  type        = string
}

variable "client_secret" {
  description = "Azure Client Secret"
  type        = string
}

# Resource group
resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "East US"
}

# Storage account
resource "azurerm_storage_account" "example" {
  name                     = "myuniqnamestrg19159" # Must be globally unique
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Storage container (bucket equivalent)
resource "azurerm_storage_container" "example" {
  name                  = "example-container"
  storage_account_id    = azurerm_storage_account.example.id
  container_access_type = "private"
}

# Outputs
output "storage_account_name" {
  value       = azurerm_storage_account.example.name
  description = "The name of the Storage Account"
}

output "storage_account_id" {
  value       = azurerm_storage_account.example.id
  description = "The ID of the Storage Account"
}

output "storage_container_name" {
  value       = azurerm_storage_container.example.name
  description = "The name of the Storage Container"
}

output "resource_group_name" {
  value       = azurerm_resource_group.example.name
  description = "The name of the Resource Group"
}
