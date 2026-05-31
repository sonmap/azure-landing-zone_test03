provider "azurerm" {
  features {}
  subscription_id = local.project_config.dev_subscription_id
}
