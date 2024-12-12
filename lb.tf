# Public IP for the Load Balancer
resource "azurerm_public_ip" "example" {
  name                = "PublicIPForLB"
  location            = "westus"
  resource_group_name = "juiceshop-rg"
  allocation_method   = "Static"
}

# Load Balancer configuration
resource "azurerm_lb" "example" {
  name                = "TestLoadBalancer"
  location            = "westus"
  resource_group_name = "juiceshop-rg"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.example.id
  }
}

# Backend Pool for Load Balancer
resource "azurerm_lb_backend_address_pool" "example" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "BackEndAddressPool"
}

# Add the container's private IP address to the backend pool
resource "azurerm_lb_backend_address_pool_address" "example" {
  name                    = "backend-address-10.0.1.4"  # Unique name for the backend address
  backend_address_pool_id = azurerm_lb_backend_address_pool.example.id
  ip_address              = "10.0.1.4"  # Your container's private IP
  virtual_network_id      = azurerm_virtual_network.vnet.id  # Reference to the existing virtual network from aci.tf
}

# Health Probe for Load Balancer (optional, but recommended)
resource "azurerm_lb_probe" "example" {
  name                = "http-probe"
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 30
  number_of_probes    = 3
  loadbalancer_id     = azurerm_lb.example.id
}

# Load Balancing Rule for Load Balancer (optional)
resource "azurerm_lb_rule" "example" {
  name                           = "HTTP-Rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.example.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.example.id]
  probe_id                       = azurerm_lb_probe.example.id
  loadbalancer_id                = azurerm_lb.example.id
}

# Outputs
output "load_balancer_ip" {
  value = azurerm_public_ip.example.ip_address
}
