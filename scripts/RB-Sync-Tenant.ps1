# ===============================================================
# 1. ERROR HANDLER: Autentikasi Managed Identity
# ===============================================================
try {
    Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
    Write-Output "Berhasil login menggunakan Managed Identity."
} catch {
    Write-Error "CRITICAL: Gagal login ke Azure menggunakan Managed Identity: $_"
    exit
}

# 2. Konfigurasi
$TenantIdentity = (Get-AutomationVariable -Name 'TenantMappingJSON' -ErrorAction SilentlyContinue | ConvertFrom-Json).TenantName

# 3. Inisialisasi struktur JSON
$MappingData = [PSCustomObject]@{
    TenantName    = $TenantIdentity
    Subscriptions = [PSCustomObject]@{}
}

# ===============================================================
# 4. Pemindaian Subscription (dengan safety check)
# ===============================================================
try {
    $allSubs = Get-AzSubscription -ErrorAction Stop
    if ($null -eq $allSubs -or $allSubs.Count -eq 0) {
        throw "Tidak ada Subscription aktif yang ditemukan/dapat diakses oleh Managed Identity."
    }
} catch {
    Write-Error "CRITICAL: Gagal mengambil daftar Subscription dari Azure: $_"
    exit
}

$freshSubscriptions = [PSCustomObject]@{}
foreach ($sub in $allSubs) {
    try {
        $freshSubscriptions | Add-Member -MemberType NoteProperty -Name $sub.Id -Value $sub.Name -Force
        Write-Output "Subscription aktif terdaftar: $($sub.Name) ($($sub.Id))"
    } catch {
        Write-Warning "Gagal memproses Subscription ID $($sub.Id): $_"
    }
}
$MappingData.Subscriptions = $freshSubscriptions

# ===============================================================
# 5. Simpan ke Automation Variable (native, tanpa modul Az.Automation tambahan)
# ===============================================================
try {
    $updatedJson = $MappingData | ConvertTo-Json -Depth 5 -Compress
    Set-AutomationVariable -Name 'TenantMappingJSON' -Value $updatedJson
    Write-Output "Sinkronisasi selesai! TenantMappingJSON telah diperbarui."
} catch {
    Write-Error "CRITICAL: Gagal menyimpan ke Automation Variable 'TenantMappingJSON': $_"
    exit
}
