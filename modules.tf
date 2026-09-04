# ==============================================================
# Modul PowerShell Az (Runtime 7.2)
# CATATAN: import modul Az via Terraform kadang lambat/timeout karena
# ukuran paket besar dan dependency chain. Jika apply gagal di sini,
# import manual lewat Portal (Modules > Browse gallery) sebagai fallback,
# lalu jalankan `terraform apply` lagi atau `terraform state rm` resource ini.
# ==============================================================

resource "azurerm_automation_module" "az_accounts" {
  name                    = "Az.Accounts"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts"
  }
}

resource "azurerm_automation_module" "az_compute" {
  name                    = "Az.Compute"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Compute"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}

resource "azurerm_automation_module" "az_resources" {
  name                    = "Az.Resources"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Resources"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}
