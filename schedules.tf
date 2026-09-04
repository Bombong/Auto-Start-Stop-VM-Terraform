# ==============================================================
# Schedule — Start VM
# ==============================================================
resource "azurerm_automation_schedule" "start_vm" {
  name                    = "Schedule-Start-VM"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  frequency               = "Day"
  interval                = 1
  timezone                = var.timezone
  start_time              = var.schedule_start_datetime
  description             = "Trigger pengecekan & start VM, jam 08:30 WIB"
}

resource "azurerm_automation_job_schedule" "start_vm_link" {
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  schedule_name            = azurerm_automation_schedule.start_vm.name
  runbook_name              = azurerm_automation_runbook.vm_onoff.name
}

# ==============================================================
# Schedule — Stop VM
# ==============================================================
resource "azurerm_automation_schedule" "stop_vm" {
  name                    = "Schedule-Stop-VM"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  frequency               = "Day"
  interval                = 1
  timezone                = var.timezone
  start_time              = var.schedule_stop_datetime
  description             = "Trigger pengecekan & deallocate VM, jam 22:30 WIB"
}

resource "azurerm_automation_job_schedule" "stop_vm_link" {
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  schedule_name            = azurerm_automation_schedule.stop_vm.name
  runbook_name              = azurerm_automation_runbook.vm_onoff.name
}
