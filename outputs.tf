output "resource_group_name" {
  description = "Nama Resource Group yang dibuat"
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Region Azure tempat resource dibuat"
  value       = azurerm_resource_group.this.location
}

output "automation_account_name" {
  description = "Nama Automation Account yang dibuat"
  value       = azurerm_automation_account.this.name
}

output "managed_identity_principal_id" {
  description = "Object (principal) ID dari Managed Identity — dipakai untuk verifikasi role assignment"
  value       = azurerm_automation_account.this.identity[0].principal_id
  sensitive   = true
}

output "role_assignment_scope" {
  description = "Scope tempat role di-assign"
  value       = var.role_scope_level == "subscription" ? "/subscriptions/${var.subscription_id}" : "Per Resource Group: ${join(", ", var.vm_resource_groups)}"
}

output "runbook_name" {
  description = "Nama Runbook utama"
  value       = azurerm_automation_runbook.vm_onoff.name
}

output "schedule_start_first_run" {
  description = "Waktu pertama Schedule Start VM akan berjalan (H+1 08:30 WIB = 01:30 UTC)"
  value       = local.schedule_start
}

output "schedule_stop_first_run" {
  description = "Waktu pertama Schedule Stop VM akan berjalan (H+1 22:30 WIB = 15:30 UTC)"
  value       = local.schedule_stop
}
