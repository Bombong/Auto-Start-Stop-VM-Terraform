# ==============================================================
# Identitas Azure tenant client
# ==============================================================
variable "tenant_id" {
  description = "Azure AD Tenant ID milik client"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.tenant_id))
    error_message = "tenant_id harus berformat UUID (contoh: 00000000-0000-0000-0000-000000000000)."
  }
}

variable "subscription_id" {
  description = "Subscription ID milik client (tempat Automation Account & VM berada)"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id harus berformat UUID (contoh: 11111111-1111-1111-1111-111111111111)."
  }
}

# ==============================================================
# Konfigurasi Automation Account
# ==============================================================
variable "client_name" {
  description = "Nama singkat client, dipakai untuk penamaan resource (mis. ClientA). Hanya huruf, angka, dan tanda hubung."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.client_name))
    error_message = "client_name hanya boleh mengandung huruf (a-z, A-Z), angka (0-9), dan tanda hubung (-). Tidak boleh ada spasi atau karakter khusus lain."
  }
}

variable "resource_group_name" {
  description = "Nama Resource Group yang akan dibuat untuk Automation Account"
  type        = string
}

variable "location" {
  description = "Region Azure, samakan dengan region VM target"
  type        = string
  default     = "southeastasia"
}

# ==============================================================
# Konfigurasi RBAC
# ==============================================================
variable "role_scope_level" {
  description = "Level scope role assignment: 'subscription' (simpel, sekali assign) atau 'resource_group' (lebih ketat)"
  type        = string
  default     = "subscription"

  validation {
    condition     = contains(["subscription", "resource_group"], var.role_scope_level)
    error_message = "role_scope_level harus 'subscription' atau 'resource_group'."
  }
}

variable "vm_resource_groups" {
  description = "Daftar nama Resource Group yang berisi VM target (dipakai hanya jika role_scope_level = 'resource_group')"
  type        = list(string)
  default     = []
}

# ==============================================================
# Automation Variables (dibaca oleh Runbook)
# ==============================================================
variable "tenant_display_name" {
  description = "Nama tenant client yang tampil di notifikasi Teams (isi awal TenantMappingJSON)"
  type        = string
}

variable "teams_webhook_url" {
  description = "URL webhook Power Automate central (sama untuk semua client)"
  type        = string
  sensitive   = true
}

variable "included_vms" {
  description = "Daftar nama/pola VM yang di-manage (mendukung wildcard, contoh: [\"VM*\", \"APP-*\"])"
  type        = list(string)
}

# ==============================================================
# Jadwal
# ==============================================================
# schedule_start_datetime & schedule_stop_datetime tidak diperlukan —
# dikalkulasi otomatis di schedules.tf (H+1 dari saat apply).
# timezone tidak diset di resource schedule karena provider azurerm ~> 3.x
# tidak mendukung timezone + start_time UTC secara bersamaan.
# Schedule disimpan dalam UTC: 01:30 UTC = 08:30 WIB, 15:30 UTC = 22:30 WIB.
