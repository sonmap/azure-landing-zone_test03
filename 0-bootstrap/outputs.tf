output "tfstate_resource_group_name" {
  value = { for key, rg in azurerm_resource_group.tfstate : key => rg.name }
}

output "tfstate_storage_account_name" {
  value = { for key, account in azurerm_storage_account.tfstate : key => account.name }
}

output "tfstate_container_name" {
  value = { for key, container in azurerm_storage_container.tfstate : key => container.name }
}
