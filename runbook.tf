# ==============================================================
# Runbook
# ==============================================================
resource "azurerm_automation_runbook" "vm_onoff" {
  name                    = "RB-VM-AutoOnOff"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  log_verbose             = true
  log_progress            = true
  description             = "Start/Deallocate VM otomatis sesuai jadwal, dengan notifikasi Teams"
  runbook_type            = "PowerShell72"

  content = file("${path.module}/scripts/RB-VM-AutoOnOff.ps1")

  depends_on = [
    azurerm_automation_module.az_accounts,
    azurerm_automation_module.az_compute,
    azurerm_automation_module.az_resources
  ]
}

resource "azurerm_automation_runbook" "sync_tenant" {
  name                    = "RB-Sync-Tenant"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  log_verbose             = true
  log_progress            = true
  description             = "Sinkronisasi daftar Subscription aktif ke TenantMappingJSON"
  runbook_type            = "PowerShell72"

  content = file("${path.module}/scripts/RB-Sync-Tenant.ps1")

  depends_on = [azurerm_automation_module.az_accounts]
}

# ==============================================================
# Automation Variables — dibaca oleh Runbook di atas
# ==============================================================
resource "azurerm_automation_variable_string" "teams_webhook" {
  name                    = "TeamsWebhookURL"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  value                   = var.teams_webhook_url
  encrypted               = true
}

resource "azurerm_automation_variable_string" "tenant_mapping" {
  name                    = "TenantMappingJSON"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  value                   = jsonencode({ TenantName = var.tenant_display_name, Subscriptions = {} })
  encrypted               = false
}

resource "azurerm_automation_variable_string" "included_vms" {
  name                    = "IncludedVMsJSON"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  value                   = jsonencode(var.included_vms)
  encrypted               = false
}

