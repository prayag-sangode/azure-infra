#provider "azurerm" {
#  features {}
#

resource "azurerm_resource_group" "rg" {
  name     = "rg-juice-shop"
  location = "East US"
}

resource "azurerm_container_group" "juice_shop" {
  name                = "juice-shop"
  location           = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  
  container {
    name   = "juice-shop"
    image  = "bkimminich/juice-shop:v15.0.0"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 3000
      protocol = "TCP"
    }
  }

  tags = {
    environment = "production"
  }
}

resource "azurerm_container_group" "nginx_proxy" {
  name                = "nginx-proxy"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  
  container {
    name   = "nginx"
    image  = "nginx:latest"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 443
      protocol = "TCP"
    }

    commands = [
      "bash",
      "-c",
      "envsubst < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && nginx -g 'daemon off;'"
    ]

    environment_variables = {
      JUICE_SHOP_URL = "http://<JuiceShop_Internal_IP>:3000"
    }
  }

  tags = {
    environment = "production"
  }
}

resource "azurerm_lb" "lb" {
  name                = "juice-shop-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "frontend-config"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  name                = "juice-shop-backend-pool"
  loadbalancer_id     = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "http_probe" {
  name                = "http-probe"
  loadbalancer_id     = azurerm_lb.lb.id
  port                = 443
  protocol            = "Https"
  request_path        = "/"
}

resource "azurerm_lb_rule" "http_rule" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
  backend_address_pool_ids      = [azurerm_lb_backend_address_pool.backend_pool.id]
  probe_id                       = azurerm_lb_probe.http_probe.id
  frontend_port                  = 443
  backend_port                   = 443
  protocol                       = "Tcp"
  enable_tcp_reset               = true
}

resource "azurerm_network_security_group" "nsg" {
  name                = "juice-shop-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "allow_zscaler" {
  name                        = "allow-zscaler"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_address_prefix       = "203.0.113.0/24" # Example Zscaler IP range
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
  destination_port_range      = "443"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_public_ip" "public_ip" {
  name                = "juice-shop-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

output "public_ip_address" {
  value = azurerm_public_ip.public_ip.ip_address
}
