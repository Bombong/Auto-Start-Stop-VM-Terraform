output "automation_account_name" {
  description = "Nama Automation Account yang dibuat"
  value       = azurerm_automation_account.this.name
}

output "managed_identity_principal_id" {
  description = "Object (principal) ID dari Managed Identity — dipakai untuk verifikasi role assignment"
  value       = azurerm_automation_account.this.identity[0].principal_id
}

output "role_assignment_scope" {
  description = "Scope tempat role di-assign"
  value       = var.role_scope_level == "subscription" ? "/subscriptions/${var.subscription_id}" : "Per Resource Group: ${join(", ", var.vm_resource_groups)}"
}

output "runbook_name" {
  description = "Nama Runbook utama"
  value       = azurerm_automation_runbook.vm_onoff.name
}
