# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "juiceshop-rg"
  location = "westus"
}
