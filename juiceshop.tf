
# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-juice-shop"
  location = "East US"
}

# Public IP (Standard SKU)
resource "azurerm_public_ip" "public_ip" {
  name                = "juice-shop-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"  # Changed from Basic to Standard
}

# Load Balancer
resource "azurerm_lb" "lb" {
  name                = "juice-shop-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
}

# Security Rules (Add source_port_range)
resource "azurerm_network_security_rule" "allow_zscaler" {
  name                        = "allow-zscaler"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_address_prefix       = "203.0.113.0/24"  # Example Zscaler IP range
  source_port_range           = "*"  # Added source port range
  destination_port_range      = "443"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "deny_other" {
  name                        = "deny-other"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"  # Added source port range
  destination_port_range      = "443"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Container Group for Juice Shop
resource "azurerm_container_group" "juice_shop" {
  name                = "juice-shop"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  container {
    name   = "juiceshop"
    image  = "bkimminich/juice-shop"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 3000
      protocol = "TCP"
    }
  }
}

# Container Group for Nginx Proxy
resource "azurerm_container_group" "nginx_proxy" {
  name                = "nginx-proxy"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  container {
    name   = "nginx-proxy"
    image  = "nginx:latest"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "juice-shop-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Load Balancer Backend Pool
resource "azurerm_lb_backend_address_pool" "backend_pool" {
  name                = "juice-shop-backend-pool"
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lb.id
}

# Load Balancer Probe
resource "azurerm_lb_probe" "http_probe" {
  name                = "http-probe"
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Http"
  port                = 80
  interval            = 15
  unhealthy_threshold = 3
}

# Load Balancer Rule
resource "azurerm_lb_rule" "http_rule" {
  name                        = "http-rule"
  resource_group_name         = azurerm_resource_group.rg.name
  loadbalancer_id             = azurerm_lb.lb.id
  protocol                    = "Tcp"
  frontend_ip_configuration_id = azurerm_lb_frontend_ip_configuration.frontend.id
  backend_address_pool_id    = azurerm_lb_backend_address_pool.backend_pool.id
  probe_id                    = azurerm_lb_probe.http_probe.id
  frontend_port              = 80
  backend_port               = 80
  enable_tcp_reset           = false
}

# Load Balancer Frontend IP Configuration
resource "azurerm_lb_frontend_ip_configuration" "frontend" {
  name                        = "frontend-ip"
  resource_group_name         = azurerm_resource_group.rg.name
  loadbalancer_id             = azurerm_lb.lb.id
  private_ip_address_allocation = "Dynamic"
}

# Assign Public IP to Frontend IP Configuration
resource "azurerm_lb_frontend_ip_configuration" "frontend_ip" {
  name                        = "frontend-ip"
  resource_group_name         = azurerm_resource_group.rg.name
  loadbalancer_id             = azurerm_lb.lb.id
  private_ip_address_allocation = "Static"
  public_ip_address_id        = azurerm_public_ip.public_ip.id
}
