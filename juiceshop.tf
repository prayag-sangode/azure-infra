# Provider Configuration
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

# 1. Resource Group
resource "azurerm_resource_group" "juice_shop_rg" {
  name     = "juice-shop-rg"
  location = "East US"
}

# 2. Virtual Network and Subnet
resource "azurerm_virtual_network" "juice_shop_vnet" {
  name                = "juice-shop-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.juice_shop_rg.location
  resource_group_name = azurerm_resource_group.juice_shop_rg.name
}

resource "azurerm_subnet" "juice_shop_subnet" {
  name                 = "juice-shop-subnet"
  resource_group_name  = azurerm_resource_group.juice_shop_rg.name
  virtual_network_name = azurerm_virtual_network.juice_shop_vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

# 3. Network Interface
resource "azurerm_network_interface" "juice_shop_nic" {
  name                = "juice-shop-nic"
  location            = azurerm_resource_group.juice_shop_rg.location
  resource_group_name = azurerm_resource_group.juice_shop_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.juice_shop_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.4"  # Static IP Address
  }
}

# 4. Azure Container Instance
resource "azurerm_container_group" "juice_shop_container" {
  name                = "juice-shop-container"
  location            = azurerm_resource_group.juice_shop_rg.location
  resource_group_name = azurerm_resource_group.juice_shop_rg.name
  os_type             = "Linux"
  tags                = {
    environment = "production"
  }

  container {
    name   = "juice-shop"
    image  = "bkimminich/juice-shop:v15.0.0"
    cpu    = "1"
    memory = "2"
    environment_variables = {
      NODE_ENV = "production"
    }

    ports {
      port     = 3000
      protocol = "TCP"
    }
  }

  # Corrected usage of subnet_ids instead of network_profile_id
  subnet_ids = [azurerm_subnet.juice_shop_subnet.id]
}
