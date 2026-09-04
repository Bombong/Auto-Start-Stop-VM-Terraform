terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

  # Diisi via variabel supaya bisa dipakai berulang untuk tiap tenant client
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
