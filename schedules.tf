# ==============================================================
# Kalkulasi waktu jadwal otomatis (selalu H+1 dari saat terraform apply)
# Tidak perlu isi tanggal manual di tfvars setiap deploy client baru.
#
# start_time pakai UTC murni ("Z") — limitasi provider azurerm ~> 3.x
# yang tidak mendukung timezone + start_time secara bersamaan.
# Konversi: 08:30 WIB = 01:30 UTC | 22:30 WIB = 15:30 UTC
# ==============================================================

locals {
  tomorrow_date_utc = formatdate("YYYY-MM-DD", timeadd(timestamp(), "24h"))
  schedule_start    = "${local.tomorrow_date_utc}T01:30:00Z" # 08:30 WIB
  schedule_stop     = "${local.tomorrow_date_utc}T15:30:00Z" # 22:30 WIB
}

# ==============================================================
# Schedule — Start VM
# ==============================================================
resource "azurerm_automation_schedule" "start_vm" {
  name                    = "Schedule-Start-VM"
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this.name
  frequency               = "Day"
  interval                = 1
  start_time              = local.schedule_start
  description             = "Trigger pengecekan & start VM — 08:30 WIB (01:30 UTC), otomatis H+1 saat apply"
}

resource "azurerm_automation_job_schedule" "start_vm_link" {
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this.name
  schedule_name           = azurerm_automation_schedule.start_vm.name
  runbook_name            = azurerm_automation_runbook.vm_onoff.name
}

# ==============================================================
# Schedule — Stop VM
# ==============================================================
resource "azurerm_automation_schedule" "stop_vm" {
  name                    = "Schedule-Stop-VM"
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this.name
  frequency               = "Day"
  interval                = 1
  start_time              = local.schedule_stop
  description             = "Trigger pengecekan & deallocate VM — 22:30 WIB (15:30 UTC), otomatis H+1 saat apply"
}

resource "azurerm_automation_job_schedule" "stop_vm_link" {
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this.name
  schedule_name           = azurerm_automation_schedule.stop_vm.name
  runbook_name            = azurerm_automation_runbook.vm_onoff.name
}
