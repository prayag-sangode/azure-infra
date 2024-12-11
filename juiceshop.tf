provider "azurerm" {
  features {}

  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# New Resource Group
resource "azurerm_resource_group" "juice_shop_new_rg" {
  name     = "juice-shop-new-rg"  # New Resource Group Name
  location = "East US"            # Location for the resource group
}

# Virtual Network
resource "azurerm_virtual_network" "juice_shop_vnet" {
  name                = "juice-shop-vnet"
  location            = azurerm_resource_group.juice_shop_new_rg.location
  resource_group_name = azurerm_resource_group.juice_shop_new_rg.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "juice_shop_subnet" {
  name                 = "juice-shop-subnet"
  resource_group_name  = azurerm_resource_group.juice_shop_new_rg.name
  virtual_network_name = azurerm_virtual_network.juice_shop_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Interface (for container group)
resource "azurerm_network_interface" "juice_shop_nic" {
  name                = "juice-shop-nic"
  location            = azurerm_resource_group.juice_shop_new_rg.location
  resource_group_name = azurerm_resource_group.juice_shop_new_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.juice_shop_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"  # Static private IP for the container
  }
}

# Container Group (with no public IP)
resource "azurerm_container_group" "juice_shop_container" {
  name                = "juice-shop-container"
  location            = azurerm_resource_group.juice_shop_new_rg.location
  resource_group_name = azurerm_resource_group.juice_shop_new_rg.name
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

  # Subnet to use internal IP
  subnet_ids = [azurerm_subnet.juice_shop_subnet.id]
}

output "resource_group_name" {
  value = azurerm_resource_group.juice_shop_new_rg.name
}

output "container_group_name" {
  value = azurerm_container_group.juice_shop_container.name
}
