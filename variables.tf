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
  description = "Nama singkat client, dipakai untuk penamaan resource (mis. ClientA)"
  type        = string
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
variable "schedule_start_datetime" {
  description = "Waktu mulai berlaku Schedule Start VM, format RFC3339, HARUS beberapa menit di masa depan saat apply (contoh: 2026-08-28T08:30:00+07:00)"
  type        = string
}

variable "schedule_stop_datetime" {
  description = "Waktu mulai berlaku Schedule Stop VM, format RFC3339 (contoh: 2026-08-28T22:30:00+07:00)"
  type        = string
}

variable "timezone" {
  description = "Timezone untuk Schedule"
  type        = string
  default     = "SE Asia Standard Time"
}
