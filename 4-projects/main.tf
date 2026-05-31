locals {
  project_config_all = {
    for row in csvdecode(file("${path.module}/csv/project_config.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }

  project_config = local.project_config_all["default"]

  workload_projects = {
    for row in csvdecode(file("${path.module}/csv/workload_projects.csv")) :
    row.key => row
    if lower(row.create) == "true"
  }
}

data "azurerm_resource_group" "workload" {
  for_each = local.workload_projects
  name     = each.value.resource_group_name
}
