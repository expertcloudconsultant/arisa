#Create a number of Resource Groups

resource "azurerm_resource_group" "corporate-tier-apps" {

    name = "corporate-tier-apps-${count.index}"
    location = var.avzs[0] #Avaialability Zone 0 always marks your Primary Region.
    count = 3
}


#Reference one of the created Resource Groups
# resource "azurerm_network_interface" "opnic" {
#   name                = "corpnic-${count.index + 1}"
#   location            = azurerm_resource_group.corporate-tier-apps.location
#   resource_group_name = azurerm_resource_group.corporate-tier-apps[1].name
#   count               = length(azurerm_resource_group.corporate-tier-apps)

#   ip_configuration {
#     name                          = "ipconfig-${count.index + 1}"
#     subnet_id                     = azurerm_subnet.business-tier-subnet.id
#     private_ip_address_allocation = "Dynamic"

#   }
# }
#az login --scope https://graph.windows.net//.default