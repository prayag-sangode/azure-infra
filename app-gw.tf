# Application Gateway Subnet
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet-${random_pet.rg_name.id}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"] # Ensure it doesn't overlap with other subnets
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_pip" {
  name                = "appgw-pip-${random_pet.rg_name.id}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Application Gateway
resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-${random_pet.rg_name.id}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "appgw-ipconfig"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_port {
    name = "frontend-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  backend_address_pool {
    name = "aci-backend-pool"
  }

  backend_http_settings {
    name                  = "backend-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = var.port
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend"
    frontend_port_name             = "frontend-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "aci-backend-pool"
    backend_http_settings_name = "backend-http-settings"
  }

  tags = {
    Environment = "Dev"
  }
}

# Add ACI to Backend Pool
resource "azurerm_application_gateway_backend_address_pool" "aci_backend" {
  name                = "aci-backend"
  application_gateway_id = azurerm_application_gateway.appgw.id

  backend_addresses {
    ip_address = azurerm_container_group.container.ip_address
  }
}

# Output for Public IP of Application Gateway
output "appgw_public_ip" {
  value = azurerm_public_ip.appgw_pip.ip_address
  description = "Public IP address of the Application Gateway"
}
