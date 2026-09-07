# ==============================================================
# Identitas Azure tenant client
# ==============================================================
variable "tenant_id" {
  description = "Azure AD Tenant ID milik client"
  type        = string
}

variable "subscription_id" {
  description = "Subscription ID milik client (tempat Automation Account & VM berada)"
  type        = string
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
  description = "Resource Group tempat Automation Account akan dibuat"
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
# schedule_start_datetime & schedule_stop_datetime dihapus —
# sekarang dikalkulasi otomatis di schedules.tf (H+1 dari saat apply).

variable "timezone" {
  description = "Timezone untuk Schedule"
  type        = string
  default     = "SE Asia Standard Time"
}
