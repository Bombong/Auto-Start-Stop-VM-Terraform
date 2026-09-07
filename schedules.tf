# ==============================================================
# Kalkulasi waktu jadwal otomatis (selalu H+1 dari saat terraform apply)
# Tidak perlu isi tanggal manual di tfvars setiap deploy client baru.
#
# Cara kerja:
#   - timestamp() menghasilkan waktu UTC saat apply dijalankan
#   - timeadd(timestamp(), "24h") → dapat tanggal esok hari UTC
#   - formatdate strip jam → dapat string "YYYY-MM-DD" esok hari
#   - Jam target di-append langsung dalam UTC (08:30 WIB = 01:30 UTC, 22:30 WIB = 15:30 UTC)
#
# Hasilnya selalu tanggal esok pukul 08:30 & 22:30 WIB,
# tidak peduli jam berapa apply dijalankan.
# ==============================================================

locals {
  # Kalkulasi jadwal otomatis — selalu H+1 dari tanggal saat terraform apply dijalankan.
  #
  # Strategi:
  #   1. Ambil tanggal H+1 dalam UTC dari timestamp() → strip jam, tambah 24h
  #   2. Set jam target di UTC:
  #      08:30 WIB = 01:30 UTC → append "T01:30:00Z"
  #      22:30 WIB = 15:30 UTC → append "T15:30:00Z"
  #
  # Dengan cara ini hasil selalu tanggal esok hari pukul XX:XX WIB,
  # tidak peduli jam berapa apply dijalankan hari ini — tidak ada edge case.
  tomorrow_date_utc = formatdate("YYYY-MM-DD", timeadd(timestamp(), "24h"))

  schedule_start = "${local.tomorrow_date_utc}T01:30:00Z" # H+1 08:30 WIB
  schedule_stop  = "${local.tomorrow_date_utc}T15:30:00Z" # H+1 22:30 WIB
}

# ==============================================================
# Schedule — Start VM
# ==============================================================
resource "azurerm_automation_schedule" "start_vm" {
  name                    = "Schedule-Start-VM"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  frequency               = "Day"
  interval                = 1
  start_time              = local.schedule_start
  description             = "Trigger pengecekan & start VM, jam 08:30 WIB (otomatis H+1 saat apply)"
}

resource "azurerm_automation_job_schedule" "start_vm_link" {
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  schedule_name           = azurerm_automation_schedule.start_vm.name
  runbook_name            = azurerm_automation_runbook.vm_onoff.name
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
  start_time              = local.schedule_stop
  description             = "Trigger pengecekan & deallocate VM, jam 22:30 WIB (otomatis H+1 saat apply)"
}

resource "azurerm_automation_job_schedule" "stop_vm_link" {
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  schedule_name           = azurerm_automation_schedule.stop_vm.name
  runbook_name            = azurerm_automation_runbook.vm_onoff.name
}
