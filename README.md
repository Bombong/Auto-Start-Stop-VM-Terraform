# Terraform — VM Auto On/Off untuk Tenant Client Baru

Provisioning otomatis: Automation Account, Managed Identity, Role Assignment, Modul PowerShell, Runbook (utama + sync tenant), Automation Variables, dan Schedule (08:30 & 22:30 WIB).

## Struktur File

```
providers.tf              # Konfigurasi provider azurerm
variables.tf               # Semua variabel input
main.tf                     # Automation Account, Managed Identity, Role Assignment
modules.tf                  # Import modul Az.Accounts, Az.Compute, Az.Resources
runbook.tf                  # Runbook + Automation Variables
schedules.tf                # Schedule Start/Stop + link ke Runbook
outputs.tf                  # Output (principal ID, dsb)
scripts/
  RB-VM-AutoOnOff.ps1       # Script Runbook utama
  RB-Sync-Tenant.ps1        # Script sync daftar Subscription
terraform.tfvars.example    # Contoh isian variabel per client
```

## Cara Pakai — Onboarding Client Baru

1. Copy seluruh folder ini (atau gunakan sebagai module Terraform terpisah per client).
2. Copy `terraform.tfvars.example` menjadi `terraform.tfvars`, isi sesuai data client (tenant ID, subscription ID, nama VM, webhook URL, dst).
3. Cek akun Azure aktif yang sedang dipakai (opsional tapi disarankan sebelum login):

   ```
   az account show
   ```

   Outputnya akan menampilkan `name` (nama subscription), `id` (subscription ID), `tenantId`, dan `user.name` (akun yang sedang login). Untuk melihat semua subscription yang bisa diakses:

   ```
   az account list --output table
   ```

4. Login ke tenant client dan set subscription aktif:
   ```
   az login --tenant <tenant_id>
   az account set --subscription <subscription_id>
   ```
   Verifikasi sudah di context yang benar:
   ```
   az account show --query "{Subscription:name, SubscriptionId:id, Tenant:tenantId, User:user.name}" --output table
   ```
5. Jalankan:
   ```
   terraform init
   terraform plan
   terraform apply
   ```
6. Setelah selesai, cek output `managed_identity_principal_id` — pastikan role assignment berhasil (bisa diverifikasi lewat Portal, IAM Subscription).
7. Login ke Azure Portal client, buka Runbook `RB-VM-AutoOnOff`, klik **Start** untuk test manual.
8. Cek Teams — pastikan notifikasi masuk.
9. Jalankan `RB-Sync-Tenant` secara manual dari Portal (Runbooks → `RB-Sync-Tenant` → Start) untuk sinkronisasi daftar Subscription aktif ke variabel `TenantMappingJSON`. Lakukan ini setiap kali ada perubahan Subscription di tenant client.

## Catatan Penting

- **Jadwal otomatis**: `schedule_start_datetime` dan `schedule_stop_datetime` sudah tidak diperlukan di `terraform.tfvars`. Waktu jadwal dikalkulasi otomatis menjadi H+1 pukul 08:30 dan 22:30 WIB dari saat `terraform apply` dijalankan — tidak perlu ubah tanggal manual setiap deploy client baru.
- **Import modul (`modules.tf`)** kadang lambat atau timeout karena ukuran paket `Az.*` cukup besar. Jika `terraform apply` gagal di step ini, import manual lewat Portal (Modules → Browse gallery) sebagai fallback, lalu lanjutkan apply untuk resource lainnya.
- **`role_scope_level`**: default `"subscription"` (Contributor di level Subscription, paling simpel, 1x assign). Ganti ke `"resource_group"` dan isi `vm_resource_groups` jika client mengharuskan akses lebih terbatas (Virtual Machine Contributor per Resource Group).
- Variabel `teams_webhook_url` ditandai `sensitive` — tidak akan tampil di log/output Terraform.
- **State file** (`terraform.tfstate`) sebaiknya disimpan di backend terpusat (Azure Storage) jika mengelola banyak client sekaligus, supaya tidak tercecer sebagai file lokal per client.

## Catatan Lain

- Script `RB-VM-AutoOnOff.ps1` hanya mengirim notifikasi ke 1 webhook central (`TeamsWebhookURL`) — tidak ada mekanisme webhook terpisah per client di versi ini.
- Waktu "Last Start/Deallocate" diambil dari `ProvisioningState.Time` VM (fungsi `Get-VMLastActionTime`), bukan Azure Activity Log — cukup akurat untuk kebutuhan normal karena Start/Deallocate memicu perubahan provisioning state, namun bisa juga terpengaruh operasi lain terhadap VM (resize, update tag, dsb) di luar Start/Deallocate.
