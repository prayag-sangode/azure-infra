# Storage Account for Terraform State
resource "azurerm_storage_account" "terraform" {
  name                     = "juiceshopstorage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "terraform" {
  name                  = "terraform-state"
  storage_account_name  = azurerm_storage_account.terraform.name
  container_access_type = "private"
}

output "storage_account_name" {
  value = azurerm_storage_account.terraform.name
}

output "storage_container_name" {
  value = azurerm_storage_container.terraform.name
}
