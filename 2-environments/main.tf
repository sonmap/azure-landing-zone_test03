locals {
  env_config_all = {
    for row in csvdecode(file("${path.module}/csv/env_config.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  env_config = local.env_config_all["default"]

  tags = {
    Environment = local.env_config.environment
    Purpose     = local.env_config.purpose
    Owner       = local.env_config.owner
    CostCenter  = local.env_config.cost_center
    ExpiryDate  = local.env_config.expiry_date
  }

  resource_groups_all = {
    for row in csvdecode(file("${path.module}/csv/resource_groups.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  department_environments_all = {
    for row in csvdecode(file("${path.module}/csv/department_environments.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  platform_resource_groups = {
    for key, row in local.resource_groups_all : key => row
    if row.subscription_key == "platform"
  }

  dev_resource_groups = {
    for key, row in local.resource_groups_all : key => row
    if row.subscription_key == "dev"
  }

  dev_department_environments = {
    for key, row in local.department_environments_all : key => row
    if row.subscription_key == "dev"
  }
}

resource "azurerm_resource_group" "platform" {
  provider = azurerm.platform
  for_each = local.platform_resource_groups

  name     = each.value.name
  location = each.value.location
  tags     = merge(local.tags, { Workload = each.value.workload, Purpose = each.value.purpose })
}

resource "azurerm_resource_group" "dev" {
  provider = azurerm.dev
  for_each = local.dev_resource_groups

  name     = each.value.name
  location = each.value.location
  tags     = merge(local.tags, { Workload = each.value.workload, Purpose = each.value.purpose })
}

resource "azurerm_resource_group" "department_dev" {
  provider = azurerm.dev
  for_each = local.dev_department_environments

  name     = each.value.resource_group_name
  location = each.value.location
  tags = merge(local.tags, {
    Department         = each.value.department
    Environment        = each.value.environment
    DataClassification = each.value.data_classification
    ApprovalRequired   = each.value.approval_required
    NetworkSpoke       = each.value.network_spoke_key
    Purpose            = "${each.value.department}-${each.value.environment}-workload-boundary"
  })
}
