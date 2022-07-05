




#Create Azure Storage Account
resource "azurerm_storage_account" "corporate-storage-account" {
  name                     = "corporatestorageacc0507"
  resource_group_name      = azurerm_resource_group.corporate-production-rg.name
  location                 = azurerm_resource_group.corporate-production-rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS" # Geographically Redundant
}


#Create NFS File Share
resource "azurerm_storage_share" "prod-nfs-share" {
  name                 = "${var.corp}-prd01nfs"
  storage_account_name = azurerm_storage_account.corporate-storage-account.name
  quota                = 100
}


#Create NFS Files or Directories
resource "azurerm_storage_share_directory" "prod" {
  name                 = element([var.nfs_fs_prod, var.nfs_fs_staging, var.nfs_fs_dev], count.index)
  share_name           = azurerm_storage_share.prod-nfs-share.name
  storage_account_name = azurerm_storage_account.corporate-storage-account.name
  count                = length(var.nfs_fs)

}
