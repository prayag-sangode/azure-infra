# Provider Configuration
#provider "azurerm" {
#  features {}
#}

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
  private_ip_address  = "10.0.0.4"
  private_ip_address_allocation = "Static"
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.juice_shop_subnet.id
    private_ip_address_allocation = "Static"
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
    ports  = ["3000"]
    environment_variables = {
      NODE_ENV = "production"
    }
  }

  network_profile_id = azurerm_network_interface.juice_shop_nic.id
}

