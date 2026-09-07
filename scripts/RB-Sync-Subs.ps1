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

# ===============================================================
# 2. Baca TenantMappingJSON untuk ambil TenantName
# ===============================================================
try {
    $TenantIdentity = (Get-AutomationVariable -Name 'TenantMappingJSON' -ErrorAction Stop | ConvertFrom-Json).TenantName
} catch {
    Write-Error "CRITICAL: Gagal membaca Automation Variable 'TenantMappingJSON': $_"
    exit
}

# ===============================================================
# 3. Inisialisasi struktur mapping baru
# ===============================================================
$MappingData = [PSCustomObject]@{
    TenantName    = $TenantIdentity
    Subscriptions = [PSCustomObject]@{}
}

# ===============================================================
# 4. Scan semua Subscription aktif yang dapat diakses
# ===============================================================
try {
    $allSubs = Get-AzSubscription -ErrorAction Stop
    if ($null -eq $allSubs -or $allSubs.Count -eq 0) {
        throw "Tidak ada Subscription aktif yang ditemukan atau dapat diakses oleh Managed Identity."
    }
} catch {
    Write-Error "CRITICAL: Gagal mengambil daftar Subscription dari Azure: $_"
    exit
}

$freshSubscriptions = [PSCustomObject]@{}
foreach ($sub in $allSubs) {
    try {
        $freshSubscriptions | Add-Member -MemberType NoteProperty -Name $sub.Id -Value $sub.Name -Force
        Write-Output "Subscription terdaftar: $($sub.Name) ($($sub.Id))"
    } catch {
        Write-Warning "Gagal memproses Subscription '$($sub.Id)': $_"
    }
}
$MappingData.Subscriptions = $freshSubscriptions

# ===============================================================
# 5. Simpan hasil ke Automation Variable TenantMappingJSON
# ===============================================================
try {
    $updatedJson = $MappingData | ConvertTo-Json -Depth 5 -Compress
    Set-AutomationVariable -Name 'TenantMappingJSON' -Value $updatedJson -ErrorAction Stop
    Write-Output "Sinkronisasi selesai. TenantMappingJSON telah diperbarui."
} catch {
    Write-Error "CRITICAL: Gagal menyimpan ke Automation Variable 'TenantMappingJSON': $_"
    exit
}
