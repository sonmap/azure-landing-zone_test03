locals {
  network_config_all = {
    for row in csvdecode(file("${path.module}/csv/network_config.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  network_config = local.network_config_all["default"]

  tags = {
    Environment = local.network_config.environment
    Purpose     = local.network_config.purpose
    Owner       = local.network_config.owner
    CostCenter  = local.network_config.cost_center
    ExpiryDate  = local.network_config.expiry_date
  }

  resource_groups_all = {
    for row in csvdecode(file("${path.module}/csv/resource_groups.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  networks_all = {
    for row in csvdecode(file("${path.module}/csv/networks.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  subnets_all = {
    for row in csvdecode(file("${path.module}/csv/subnets.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  routes_all = {
    for row in csvdecode(file("${path.module}/csv/routes.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  hub_entry_all = {
    for row in csvdecode(file("${path.module}/csv/hub_entry.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  hub_entry_public_ip = {
    for key, row in local.hub_entry_all :
    key => row
    if try(lower(trimspace(row.create_public_ip)), "true") == "true"
  }

  nsg_rules_all = {
    for row in csvdecode(file("${path.module}/csv/nsg_rules.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  private_dns_zones_all = {
    for row in csvdecode(file("${path.module}/csv/private_dns_zones.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  hub_rg_name = local.resource_groups_all["hub"].name
  dev_rg_name = local.resource_groups_all["dev"].name

  platform_networks = {
    for key, row in local.networks_all : key => row
    if row.subscription_key == "platform"
  }

  dev_networks = {
    for key, row in local.networks_all : key => row
    if row.subscription_key == "dev"
  }

  platform_subnets = {
    for key, row in local.subnets_all : key => row
    if row.subscription_key == "platform"
  }

  dev_subnets = {
    for key, row in local.subnets_all : key => row
    if row.subscription_key == "dev"
  }

  dev_routes = {
    for key, row in local.routes_all : key => row
    if row.subscription_key == "dev"
  }
}

data "azurerm_resource_group" "hub" {
  provider = azurerm.platform
  name     = local.hub_rg_name
}

data "azurerm_resource_group" "dev" {
  provider = azurerm.dev
  name     = local.dev_rg_name
}

resource "azurerm_virtual_network" "hub" {
  provider = azurerm.platform
  for_each = local.platform_networks

  name                = each.value.name
  location            = data.azurerm_resource_group.hub.location
  resource_group_name = data.azurerm_resource_group.hub.name
  address_space       = [each.value.address_space]
  tags                = merge(local.tags, { Purpose = each.value.purpose })
}

resource "azurerm_subnet" "platform" {
  provider = azurerm.platform
  for_each = local.platform_subnets

  name                 = each.value.name
  resource_group_name  = data.azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub[each.value.network_key].name
  address_prefixes     = [each.value.address_prefix]
}

resource "azurerm_virtual_network" "spoke" {
  provider = azurerm.dev
  for_each = local.dev_networks

  name                = each.value.name
  location            = data.azurerm_resource_group.dev.location
  resource_group_name = data.azurerm_resource_group.dev.name
  address_space       = [each.value.address_space]
  tags                = merge(local.tags, { Purpose = each.value.purpose })
}

resource "azurerm_subnet" "spoke" {
  provider = azurerm.dev
  for_each = local.dev_subnets

  name                 = each.value.name
  resource_group_name  = data.azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.spoke[each.value.network_key].name
  address_prefixes     = [each.value.address_prefix]
}

resource "azurerm_public_ip" "hub_entry" {
  provider = azurerm.platform
  #  for_each = local.hub_entry_all
  for_each            = local.hub_entry_public_ip
  name                = each.value.public_ip_name
  location            = data.azurerm_resource_group.hub.location
  resource_group_name = data.azurerm_resource_group.hub.name
  allocation_method   = each.value.public_ip_allocation_method
  sku                 = each.value.public_ip_sku
  tags                = local.tags
}

resource "azurerm_network_security_group" "hub_nva" {
  provider = azurerm.platform
  for_each = local.hub_entry_all

  name                = each.value.nsg_name
  location            = data.azurerm_resource_group.hub.location
  resource_group_name = data.azurerm_resource_group.hub.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "hub_nva" {
  provider = azurerm.platform
  for_each = local.nsg_rules_all

  name                        = each.value.name
  priority                    = tonumber(each.value.priority)
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix == "admin_source_cidr" ? local.network_config.admin_source_cidr : each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = data.azurerm_resource_group.hub.name
  network_security_group_name = azurerm_network_security_group.hub_nva[each.value.nsg_key].name
}

resource "azurerm_network_interface" "hub_nva" {
  provider = azurerm.platform
  for_each = local.hub_entry_all

  name                  = each.value.nic_name
  location              = data.azurerm_resource_group.hub.location
  resource_group_name   = data.azurerm_resource_group.hub.name
  ip_forwarding_enabled = true
  tags                  = local.tags

  ip_configuration {
    name                          = each.value.ip_configuration_name
    subnet_id                     = azurerm_subnet.platform["hub_public_entry"].id
    private_ip_address_allocation = each.value.private_ip_allocation
    private_ip_address            = each.value.private_ip_address
    #public_ip_address_id          = azurerm_public_ip.hub_entry[each.key].id
    public_ip_address_id = try(azurerm_public_ip.hub_entry[each.key].id, null)
  }
}

resource "azurerm_network_interface_security_group_association" "hub_nva" {
  provider = azurerm.platform
  for_each = local.hub_entry_all

  network_interface_id      = azurerm_network_interface.hub_nva[each.key].id
  network_security_group_id = azurerm_network_security_group.hub_nva[each.key].id
}

resource "azurerm_linux_virtual_machine" "hub_nva" {
  provider = azurerm.platform
  for_each = local.hub_entry_all

  name                            = each.value.vm_name
  location                        = data.azurerm_resource_group.hub.location
  resource_group_name             = data.azurerm_resource_group.hub.name
  size                            = each.value.vm_size
  admin_username                  = local.network_config.vm_admin_username
  admin_password                  = local.network_config.vm_admin_password
  disable_password_authentication = lower(each.value.vm_admin_disable_password_authentication) == "true"
  network_interface_ids           = [azurerm_network_interface.hub_nva[each.key].id]
  tags                            = local.tags

  os_disk {
    caching              = each.value.os_disk_caching
    storage_account_type = each.value.os_disk_storage_account_type
  }

  source_image_reference {
    publisher = each.value.image_publisher
    offer     = each.value.image_offer
    sku       = each.value.image_sku
    version   = each.value.image_version
  }
}

resource "azurerm_route_table" "spoke" {
  provider = azurerm.dev
  for_each = local.dev_routes

  name                = each.value.route_table_name
  location            = data.azurerm_resource_group.dev.location
  resource_group_name = data.azurerm_resource_group.dev.name
  tags                = merge(local.tags, { Purpose = each.value.purpose })

  route {
    name                   = each.value.route_name
    address_prefix         = each.value.address_prefix
    next_hop_type          = each.value.next_hop_type
    next_hop_in_ip_address = each.value.next_hop_type == local.network_config.virtual_appliance_next_hop_type ? each.value.next_hop_in_ip_address : null
  }
}

resource "azurerm_subnet_route_table_association" "spoke" {
  provider = azurerm.dev
  for_each = local.dev_routes

  subnet_id      = azurerm_subnet.spoke[each.value.subnet_key].id
  route_table_id = azurerm_route_table.spoke[each.key].id
}

resource "azurerm_private_dns_zone" "zones" {
  provider = azurerm.platform
  for_each = local.private_dns_zones_all

  name                = each.value.name
  resource_group_name = data.azurerm_resource_group.hub.name
  tags                = local.tags
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider = azurerm.platform
  for_each = azurerm_virtual_network.spoke

  name                      = "peer-hub-to-${each.key}"
  resource_group_name       = data.azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub["hub"].name
  remote_virtual_network_id = each.value.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  provider = azurerm.dev
  for_each = azurerm_virtual_network.spoke

  name                      = "peer-${each.key}-to-hub"
  resource_group_name       = data.azurerm_resource_group.dev.name
  virtual_network_name      = each.value.name
  remote_virtual_network_id = azurerm_virtual_network.hub["hub"].id
  allow_forwarded_traffic   = true
}
