terraform {
  required_version = ">= 1.6.0, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.117.1"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 2.53.1"
    }
  }
  backend "azurerm" {} # Configure with -backend-config (environment state key).
}
provider "azurerm" {
  features {
    key_vault { purge_soft_delete_on_destroy = false }
  }
}
provider "azuread" {}
