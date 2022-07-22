#Use Output to Find Information

output "corpvnetid" {

  value = azurerm_virtual_network.corporate-prod-vnet.id
}

output "hubvnetid" {

  value = azurerm_virtual_network.corporate-hub-vnet.id
}



output  "linuxvmsshkey" { #tls_private_key

  value = tls_private_key.linuxvmsshkey.public_key_openssh
  sensitive = true
}