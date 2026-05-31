provider "azurerm" {
  alias = "platform"
  features {}
  subscription_id = local.org_config.platform_subscription_id
}

provider "azurerm" {
  alias = "dev"
  features {}
  subscription_id = local.org_config.dev_subscription_id
}
