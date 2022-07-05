resource "azurerm_network_interface" "corporate-management-vmss-nic" {
  name                 = "corporate-management-vmss-nic"
  location             = azurerm_resource_group.corporate-production-rg.location
  resource_group_name  = azurerm_resource_group.corporate-production-rg.name
  enable_ip_forwarding = false

  #Associate Public IP Addressing to Network Interface
  ip_configuration {
    name                          = "corporate-management-vmss-ip"
    subnet_id                     = azurerm_subnet.hub-management-subnet.id #Associate NIC to the Corporate management Subnet
    private_ip_address_allocation = "Dynamic"                               #Azure's Dynamic Allocation of IP Addressing starting from .4 of that Subnet's CIDR.
    #public_ip_address_id          = azurerm_public_ip.corporate-management-vm-pubip.id #Associate the Private NIC to the Public IP.
  }

}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "corporate-management-nsg" {
  name                = "corporate-management-nsg"
  location            = azurerm_resource_group.corporate-production-rg.location
  resource_group_name = azurerm_resource_group.corporate-production-rg.name


  #Add rule for Inbound Access
  security_rule {
    name                       = "RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.rdp_access_port # Referenced RDP Port 33 from vars.tf file.
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


#Connect NSG to Subnet
resource "azurerm_subnet_network_security_group_association" "corporate-management-nsg-assoc" {
  subnet_id                 = azurerm_subnet.hub-management-subnet.id
  network_security_group_id = azurerm_network_security_group.corporate-management-nsg.id
}


#Create scaleset for management
resource "azurerm_windows_virtual_machine_scale_set" "corporate-management-vm" {
  #name                = "${var.corp}-${var.mgmt}-${var.webres[0]}"
  name = "mgmtssvm"
  resource_group_name = azurerm_resource_group.corporate-production-rg.name
  location            = azurerm_resource_group.corporate-production-rg.location
  sku                = "Standard_B1s" #"Standard_D2s_v3"
  instances           = 2
  admin_password      = "P@55w0rd1234!"
  admin_username      = "adminuser"

  #Source Image from Publisher
  source_image_reference {
    publisher = "MicrosoftWindowsServer"    #az vm image list -p "Microsoft" --output table
    offer     = "WindowsServer"             # az vm image list --offer "WindowsServer" --output table
    sku       = "2019-datacenter-gensecond" # az vm image list -s "2019-Datacenter" --output table
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" #Consider Storage Type
  }

  network_interface {
    name    = "corporate-management-vm-nic"
    primary = true

    ip_configuration {
      name      = "privatenic"
      primary   = true
      subnet_id = azurerm_subnet.hub-management-subnet.id
    }
  }

}