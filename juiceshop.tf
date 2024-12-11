# Create a Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${random_pet.rg_name.id}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Create a Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-${random_pet.rg_name.id}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Updated Container Group
resource "azurerm_container_group" "container" {
  name                = "${var.container_group_name_prefix}-${random_string.container_name.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_address_type     = "Private"
  os_type             = "Linux"
  restart_policy      = var.restart_policy

  subnet_ids = [azurerm_subnet.subnet.id] # Assign the subnet to the container group

  container {
    name   = "${var.container_name_prefix}-${random_string.container_name.result}"
    image  = var.image
    cpu    = var.cpu_cores
    memory = var.memory_in_gb

    ports {
      port     = var.port
      protocol = "TCP"
    }
  }
}

output "container_ipv4_address" {
  value = azurerm_container_group.container.ip_address
}
