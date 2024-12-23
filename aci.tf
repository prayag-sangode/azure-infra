# Virtual Network and Subnet with Delegation
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-juiceshop"
  location            = "westus"
  resource_group_name = "juiceshop-rg"
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-juiceshop"
  resource_group_name  = "juiceshop-rg"
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "aci-delegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_container_group" "container" {
  name                = "juiceshop-aci-group"
  location            = "westus"
  resource_group_name = "juiceshop-rg"
  os_type             = "Linux"
  restart_policy      = "Always"
  subnet_ids          = [azurerm_subnet.subnet.id]  # Subnet for private IP
  ip_address_type     = "Private"                  # Must use private IP for subnet

  container {
    name   = "juiceshop-container101"
    #image  = "bkimminich/juice-shop:latest"
    image = "mcr.microsoft.com/azuredocs/aci-helloworld"
    cpu    = "1"
    memory = "2"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }
}

# Outputs
output "container_ipv4_address" {
  value = azurerm_container_group.container.ip_address
}
