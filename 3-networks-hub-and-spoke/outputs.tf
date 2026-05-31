output "hub_vnet_id" {
  value = azurerm_virtual_network.hub["hub"].id
}

output "hub_public_ip_id" {
  value = { for key, public_ip in azurerm_public_ip.hub_entry : key => public_ip.id }
}

output "spoke_vnet_ids" {
  value = { for key, vnet in azurerm_virtual_network.spoke : key => vnet.id }
}

output "csv_routes" {
  value = local.routes_all
}
