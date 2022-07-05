#Create Resource Groups
resource "azurerm_resource_group" "corporate-production-rg" {
  name     = "corporate-production-rg"
  location = var.avzs[0] #Avaialability Zone 0 always marks your Primary Region.
}




#Create Virtual Networks > Create Hub Virtual Network
resource "azurerm_virtual_network" "corporate-hub-vnet" {
  name                = "corporate-hub-vnet"
  location            = azurerm_resource_group.corporate-production-rg.location
  resource_group_name = azurerm_resource_group.corporate-production-rg.name
  address_space       = ["172.20.0.0/16"]

  tags = {
    environment = "Hub Network"
  }
}

#Create Hub Azure Gateway Subnet
resource "azurerm_subnet" "hub-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.corporate-production-rg.name
  virtual_network_name = azurerm_virtual_network.corporate-hub-vnet.name
  address_prefixes     = ["172.20.0.0/24"]
}



#Create Hub Azure Gateway Subnet
resource "azurerm_subnet" "hub-management-subnet" {
  name                 = "hub-management-subnet"
  resource_group_name  = azurerm_resource_group.corporate-production-rg.name
  virtual_network_name = azurerm_virtual_network.corporate-hub-vnet.name
  address_prefixes     = ["172.20.10.0/24"]
}



#Create Virtual Networks > Create Spoke Virtual Network
resource "azurerm_virtual_network" "corporate-prod-vnet" {
  name                = "corporate-prod-vnet"
  location            = azurerm_resource_group.corporate-production-rg.location
  resource_group_name = azurerm_resource_group.corporate-production-rg.name
  address_space       = ["10.20.0.0/16"]

  tags = {
    environment = "Production Network"
  }
}

#Create Hub Azure Gateway Subnet
resource "azurerm_subnet" "business-tier-subnet" {
  name                 = "business-tier-subnet"
  resource_group_name  = azurerm_resource_group.corporate-production-rg.name
  virtual_network_name = azurerm_virtual_network.corporate-prod-vnet.name
  address_prefixes     = ["10.20.10.0/24"]
}



##########virtual##################network#############peering###########################
#Create Network Peering from Hub to Spoke
resource "azurerm_virtual_network_peering" "hub-to-prod-spoke-peering" {
  name                      = "hub-corp-spoke-peering"
  resource_group_name       = azurerm_resource_group.corporate-production-rg.name
  virtual_network_name      = azurerm_virtual_network.corporate-hub-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.corporate-prod-vnet.id
}
##########virtual##################network#############peering###########################



##########virtual##################network#############peering###########################
#Create Network Peering from Spoke to Hub
resource "azurerm_virtual_network_peering" "corp-to-hub-spoke-peering" {
  name                      = "corp-hub-spoke-peering"
  resource_group_name       = azurerm_resource_group.corporate-production-rg.name
  virtual_network_name      = azurerm_virtual_network.corporate-prod-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.corporate-hub-vnet.id
}
##########virtual##################network#############peering###########################



#Create Private Network Interfaces
resource "azurerm_network_interface" "corpnic" {
  name                = "corpnic-${count.index + 1}"
  location            = azurerm_resource_group.corporate-production-rg.location
  resource_group_name = azurerm_resource_group.corporate-production-rg.name
  count               = 2

  ip_configuration {
    name                          = "ipconfig-${count.index + 1}"
    subnet_id                     = azurerm_subnet.business-tier-subnet.id
    private_ip_address_allocation = "Dynamic"

  }
}


#Create Load Balancer
resource "azurerm_lb" "business-tier-lb" {
  name                = "business-tier-lb"
  location            = azurerm_resource_group.corporate-production-rg.location
  resource_group_name = azurerm_resource_group.corporate-production-rg.name

  frontend_ip_configuration {
    name                          = "businesslbfrontendip"
    subnet_id                     = azurerm_subnet.business-tier-subnet.id
    private_ip_address            = var.env == "Static" ? var.private_ip : null
    private_ip_address_allocation = var.env == "Static" ? "Static" : "Dynamic"
  }
}



#Create Loadbalancing Rules
resource "azurerm_lb_rule" "production-inbound-rules" {
  loadbalancer_id                = azurerm_lb.business-tier-lb.id
  resource_group_name            = azurerm_resource_group.corporate-production-rg.name
  name                           = "ssh-inbound-rule"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = "businesslbfrontendip"
  probe_id                       = azurerm_lb_probe.ssh-inbound-probe.id
  backend_address_pool_ids        = ["${azurerm_lb_backend_address_pool.business-backend-pool.id}"]
 

}


#Create Probe
resource "azurerm_lb_probe" "ssh-inbound-probe" {
  resource_group_name = azurerm_resource_group.corporate-production-rg.name
  loadbalancer_id     = azurerm_lb.business-tier-lb.id
  name                = "ssh-inbound-probe"
  port                = 22
}




#Create Backend Address Pool
resource "azurerm_lb_backend_address_pool" "business-backend-pool" {
  loadbalancer_id = azurerm_lb.business-tier-lb.id
  name            = "business-backend-pool"
}



#Automated Backend Pool Addition > Gem Configuration
resource "azurerm_network_interface_backend_address_pool_association" "business-tier-pool" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.corpnic.*.id[count.index]
  ip_configuration_name   = azurerm_network_interface.corpnic.*.ip_configuration.0.name[count.index]
  backend_address_pool_id = azurerm_lb_backend_address_pool.business-backend-pool.id

}


#Create Virtual Network Gateway Public IP
resource "azurerm_public_ip" "corp-vngw-pip" {
  name                = "corp-vngw-pip"
  location            = azurerm_resource_group.corporate-production-rg.location
  resource_group_name = azurerm_resource_group.corporate-production-rg.name

  allocation_method = "Dynamic"
}

#Create the Virtual Network Gateway Resource
resource "azurerm_virtual_network_gateway" "hub-virtual-network-gateway" {
  name                = "hub-virtual-network-gateway"
  location            = azurerm_resource_group.corporate-production-rg.location
  resource_group_name = azurerm_resource_group.corporate-production-rg.name

  #Specify VPN Type
  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "Standard"


  #Construct the Virtual Network Gateway Integration with Public IP
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.corp-vngw-pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub-gateway-subnet.id
  }



  #Create Custom Route
  custom_route {
    address_prefixes = ["10.20.0.0/16"] # 
  }


  vpn_client_configuration {
    address_space        = ["192.168.8.0/24"] #
    vpn_auth_types       = ["AAD"]
    vpn_client_protocols = ["OpenVPN"]
    aad_tenant           = "https://login.microsoftonline.com/${var.tenant_id}" # enant_id from azure portal
    aad_issuer           = "https://sts.windows.net/${var.tenant_id}/"          #  Tenant_id = az account show (az cli) 
    aad_audience         = "41b23e61-6c1e-4545-b367-cd054e0ed4b4"               # This remains constant - does not change
  }

}


