#Use Output to Find Information

output "corpvnetid" {

  value = azurerm_virtual_network.corporate-prod-vnet.id
}

output "hubvnetid" {

  value = azurerm_virtual_network.corporate-hub-vnet.id
}