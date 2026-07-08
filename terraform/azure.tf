# ============================================================================
# Azure Multi-Cloud Resources
# Only provisioned when enable_azure = true
# ============================================================================

# Resource Group
resource "azurerm_resource_group" "radahn" {
  count    = var.enable_azure ? 1 : 0
  name     = var.azure_resource_group
  location = var.azure_location

  tags = {
    Project     = "Radahn"
    ManagedBy   = "Terraform"
    Environment = "Multi-Cloud"
  }
}

# ============================================================================
# Virtual Network (VNet) — 10.1.0.0/16
# ============================================================================

resource "azurerm_virtual_network" "radahn" {
  count               = var.enable_azure ? 1 : 0
  name                = "radahn-vnet"
  location            = azurerm_resource_group.radahn[0].location
  resource_group_name = azurerm_resource_group.radahn[0].name
  address_space       = ["10.1.0.0/16"]

  tags = { Project = "Radahn" }
}

resource "azurerm_subnet" "private" {
  count                = var.enable_azure ? 1 : 0
  name                 = "radahn-private-subnet"
  resource_group_name  = azurerm_resource_group.radahn[0].name
  virtual_network_name = azurerm_virtual_network.radahn[0].name
  address_prefixes     = ["10.1.1.0/24"]
}

# Gateway Subnet — required by Azure VPN Gateway (must be named "GatewaySubnet")
resource "azurerm_subnet" "gateway" {
  count                = var.enable_vpn ? 1 : 0
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.radahn[0].name
  virtual_network_name = azurerm_virtual_network.radahn[0].name
  address_prefixes     = ["10.1.255.0/27"]
}

# ============================================================================
# Network Security Group
# ============================================================================

resource "azurerm_network_security_group" "radahn" {
  count               = var.enable_azure ? 1 : 0
  name                = "radahn-nsg"
  location            = azurerm_resource_group.radahn[0].location
  resource_group_name = azurerm_resource_group.radahn[0].name

  security_rule {
    name                       = "allow-ssh-from-aws"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/16"  # AWS VPC CIDR
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-internal"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }

  tags = { Project = "Radahn" }
}

# ============================================================================
# VPN Gateway — Site-to-Site to AWS (only when enable_vpn = true)
# NOTE: This resource takes 30-45 minutes to provision
# ============================================================================

resource "azurerm_public_ip" "vpn_gateway" {
  count               = var.enable_vpn ? 1 : 0
  name                = "radahn-vpngw-pip"
  location            = azurerm_resource_group.radahn[0].location
  resource_group_name = azurerm_resource_group.radahn[0].name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = { Project = "Radahn" }
}

resource "azurerm_virtual_network_gateway" "radahn" {
  count               = var.enable_vpn ? 1 : 0
  name                = "radahn-vpngw"
  location            = azurerm_resource_group.radahn[0].location
  resource_group_name = azurerm_resource_group.radahn[0].name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  enable_bgp          = false

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway[0].id
  }

  tags = { Project = "Radahn" }
}

# Local Network Gateway — represents AWS side
resource "azurerm_local_network_gateway" "aws_side" {
  count               = var.enable_vpn ? 1 : 0
  name                = "radahn-aws-local-gw"
  location            = azurerm_resource_group.radahn[0].location
  resource_group_name = azurerm_resource_group.radahn[0].name
  # AWS VPN will provide the public IP — filled by aws_vpn_connection output
  gateway_address     = "1.2.3.4"  # Placeholder — update after AWS VPN deploy
  address_space       = ["10.0.0.0/16"]

  tags = { Project = "Radahn" }
}

resource "azurerm_virtual_network_gateway_connection" "aws_vpn" {
  count                      = var.enable_vpn ? 1 : 0
  name                       = "radahn-to-aws"
  location                   = azurerm_resource_group.radahn[0].location
  resource_group_name        = azurerm_resource_group.radahn[0].name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.radahn[0].id
  local_network_gateway_id   = azurerm_local_network_gateway.aws_side[0].id
  shared_key                 = "RadahnMultiCloud2026!"

  tags = { Project = "Radahn" }
}

# ============================================================================
# Outputs — used by generate_dashboard.py
# ============================================================================

output "azure_vnet_id" {
  value = var.enable_azure ? azurerm_virtual_network.radahn[0].id : ""
}

output "azure_vnet_cidr" {
  value = var.enable_azure ? azurerm_virtual_network.radahn[0].address_space[0] : ""
}

output "azure_vpn_public_ip" {
  value = var.enable_vpn ? azurerm_public_ip.vpn_gateway[0].ip_address : ""
}

output "azure_resource_group" {
  value = var.enable_azure ? azurerm_resource_group.radahn[0].name : ""
}
