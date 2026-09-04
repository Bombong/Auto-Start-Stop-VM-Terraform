# ==============================================================
# Kalkulasi waktu jadwal otomatis (H+1 dari saat terraform apply)
# Tidak perlu isi tanggal manual di tfvars setiap deploy client baru.
#
# Cara kerja:
#   - timestamp() menghasilkan waktu UTC saat apply dijalankan
#   - timeadd menambah offset jam ke waktu tersebut
#   - formatdate memformat ke RFC3339 yang dibutuhkan Azure
#
# Offset dihitung dari UTC:
#   WIB = UTC+7, jadi:
#     08:30 WIB = 01:30 UTC → timeadd H+1 00:00 UTC + 1.5 jam  = +25.5 jam dari tengah malam UTC H+0
#     22:30 WIB = 15:30 UTC → timeadd H+1 00:00 UTC + 15.5 jam = +39.5 jam dari tengah malam UTC H+0
#
# Namun karena timestamp() bukan tengah malam, kita cukup ambil "H+1 pukul XX:XX WIB"
# dengan cara: floor ke hari ini (UTC) + 1 hari + offset jam WIB ke UTC
# Pendekatan paling simpel: pakai timeadd dari timestamp() dengan asumsi apply
# dilakukan jauh sebelum jadwal (jika apply dilakukan siang, H+1 08:30 masih valid).
# ==============================================================

locals {
  # Ambil tanggal hari ini UTC (strip jam), tambah 1 hari, lalu set jam target dalam UTC
  # 08:30 WIB = 01:30 UTC  → offset dari tengah malam UTC hari ini: +25h30m
  # 22:30 WIB = 15:30 UTC  → offset dari tengah malam UTC hari ini: +39h30m
  #
  # Untuk dapat "tengah malam UTC hari ini", kita strip jam dari timestamp()
  # dengan memformat ke "YYYY-MM-DD" lalu append "T00:00:00Z"
  today_midnight_utc = "${formatdate("YYYY-MM-DD", timestamp())}T00:00:00Z"

  schedule_start = timeadd(local.today_midnight_utc, "25h30m") # H+1 08:30 WIB
  schedule_stop  = timeadd(local.today_midnight_utc, "39h30m") # H+1 22:30 WIB
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
  timezone                = var.timezone
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
  timezone                = var.timezone
  start_time              = local.schedule_stop
  description             = "Trigger pengecekan & deallocate VM, jam 22:30 WIB (otomatis H+1 saat apply)"
}

resource "azurerm_automation_job_schedule" "stop_vm_link" {
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  schedule_name           = azurerm_automation_schedule.stop_vm.name
  runbook_name            = azurerm_automation_runbook.vm_onoff.name
}
