provider "azurerm" {
  alias = "platform"
  features {}
  subscription_id = local.env_config.platform_subscription_id
}

provider "azurerm" {
  alias = "dev"
  features {}
  subscription_id = local.env_config.dev_subscription_id
}
