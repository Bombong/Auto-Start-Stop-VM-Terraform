# ==============================================================
# Local — Tags terpusat, dipakai semua resource
# ==============================================================
locals {
  common_tags = {
    client  = var.client_name
    purpose = "vm-auto-onoff"
  }
}

# ==============================================================
# Resource Group
# ==============================================================
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# ==============================================================
# Automation Account
# ==============================================================
resource "azurerm_automation_account" "this" {
  name                = "AutomationVM-${var.client_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# ==============================================================
# Role Assignment — scope Subscription (default)
# ==============================================================
resource "azurerm_role_assignment" "contributor_subscription" {
  count                = var.role_scope_level == "subscription" ? 1 : 0
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.this.identity[0].principal_id
}

# ==============================================================
# Role Assignment alternatif — per Resource Group (lebih ketat, opsional)
# Aktifkan dengan set role_scope_level = "resource_group" dan isi var.vm_resource_groups
# ==============================================================
resource "azurerm_role_assignment" "vm_contributor_rg" {
  for_each             = var.role_scope_level == "resource_group" ? toset(var.vm_resource_groups) : toset([])
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${each.value}"
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_automation_account.this.identity[0].principal_id
}
