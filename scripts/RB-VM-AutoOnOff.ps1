# ===============================================================
# 1. ERROR HANDLER GLOBAL: Autentikasi & Inisialisasi Variabel
# ===============================================================
try {
    Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
    
    $Webhook      = Get-AutomationVariable -Name 'TeamsWebhookURL' -ErrorAction Stop
    $Mapping      = (Get-AutomationVariable -Name 'TenantMappingJSON' -ErrorAction Stop) | ConvertFrom-Json
    $Includes     = (Get-AutomationVariable -Name 'IncludedVMsJSON' -ErrorAction Stop) | ConvertFrom-Json
    
} catch {
    Write-Error "CRITICAL: Gagal melakukan inisialisasi awal atau membaca variabel: $_"
    exit
}

$wibNow = [TimeZoneInfo]::ConvertTime((Get-Date), [TimeZoneInfo]::FindSystemTimeZoneById("SE Asia Standard Time"))
$isWork = ($wibNow.TimeOfDay -ge [TimeSpan]"08:30" -and $wibNow.TimeOfDay -lt [TimeSpan]"22:30")
$jobs   = [System.Collections.Generic.List[PSObject]]::new()

# ===============================================================
# 2. FUNCTION: Ambil Last Running dari Activity Log 
# ===============================================================
function Get-VMLastActionTime ($resourceGroupName, $vmName) {
    try {
        $vmDetail = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Status -ErrorAction Stop
        $provisioningStatus = $vmDetail.Statuses | Where-Object Code -like "ProvisioningState/*" | Select-Object -First 1

        if ($provisioningStatus -and $provisioningStatus.Time) {
            $tzWIB = [TimeZoneInfo]::FindSystemTimeZoneById("SE Asia Standard Time")
            return [TimeZoneInfo]::ConvertTime($provisioningStatus.Time, $tzWIB).ToString("dd-MM-yyyy HH:mm:ss")
        }

        return "Log tidak ditemukan"
    } catch {
        Write-Warning "Gagal ambil status VM '$vmName': $_"
        return "Gagal mengambil log"
    }
}

# ===============================================================
# 3. FUNCTION TEAMS Adaptive Card
# ===============================================================
function Send-Teams ($vmName, $statusText, $subId, $tenantName, $lastRunTime) {
    if (-not $lastRunTime) {
        $lastRunTimeText = "N/A"
    } else {
        $lastRunTimeText = $lastRunTime
    }

    $lastTimeLabel = if ($powerStatus.Code -eq "PowerState/running") {
    "Last Start Time (WIB):"
    }
    elseif ($powerStatus.Code -eq "PowerState/deallocated") {
    "Last Deallocate Time (WIB):"
    }
    else {
    "Last Status/Run Time (WIB):"
    }

    $card = @{
        type = "message"; attachments = @(@{
            contentType = "application/vnd.microsoft.card.adaptive"
            content     = @{
                '$schema' = "http://adaptivecards.io/schemas/adaptive-card.json"
                type = "AdaptiveCard"; version = "1.4"
                body = @(
                    @{ type = "TextBlock"; size = "Medium"; weight = "Bolder"; text = "Azure Virtual Machine Status Update" },
                    @{ type = "FactSet"; facts = @(
                        @{ title = "Nama Tenant:"; value = $tenantName },
                        @{ title = "Subscription ID:"; value = $subId },
                        @{ title = "Nama Virtual Machine:"; value = $vmName },
                        @{ title = "Status Virtual Machine:"; value = $statusText },
                        @{ title = $lastTimeLabel; value = $lastRunTimeText },
                        @{ title = "Waktu Pengecekan Terakhir (WIB):"; value = $wibNow.ToString("dd-MM-yyyy HH:mm:ss") }
                    )}
                )
            }
        })
    } | ConvertTo-Json -Depth 10

    # 1. Kirim ke Webhook Power Automate
    try {
        Invoke-RestMethod -Uri $Webhook -Method Post -ContentType "application/json" -Body $card -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "Gagal kirim ke Central Webhook untuk '$vmName': $_"
    }
}

# ===============================================================
# 4. ERROR HANDLER PER-SUBSCRIPTION & PER-VM
# ===============================================================
foreach ($sub in Get-AzSubscription) {
    try {
        $ctx    = Set-AzContext -SubscriptionId $sub.Id -ErrorAction Stop
        $tenant = if ($Mapping.TenantName) { $Mapping.TenantName } else { $ctx.Tenant.Directory }
        $allVMs = Get-AzVM -ErrorAction Stop  # TANPA -Status, cuma untuk dapat daftar nama VM

        foreach ($vmBasic in $allVMs) {
            if (-not ($Includes | Where-Object { $vmBasic.Name -like $_ })) { continue }

            try {
                # Query per-VM dengan -Status
                $vm = Get-AzVM -ResourceGroupName $vmBasic.ResourceGroupName -Name $vmBasic.Name -Status -ErrorAction Stop
                $powerStatus = $vm.Statuses | Where-Object Code -like "PowerState*"
                $isRun       = $powerStatus.Code -eq "PowerState/running"
                # Ambil timestamp aksi terakhir di Azure Activity Log
                $vmLastTimeWIB = Get-VMLastActionTime -resourceGroupName $vm.ResourceGroupName -vmName $vm.Name

                if ($isWork -and -not $isRun) {
                    $job = Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -AsJob -ErrorAction Stop
                    $jobs.Add($job)
                    Send-Teams $vm.Name "Running (Proses Dinyalakan)" $sub.Id $tenant $vmLastTimeWIB
                } 
                elseif (-not $isWork -and $isRun) {
                    $job = Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force -AsJob -ErrorAction Stop
                    $jobs.Add($job)
                    Send-Teams $vm.Name "Deallocated (Proses Dimatikan)" $sub.Id $tenant $vmLastTimeWIB
                } 
                else {
                    $state = if ($isRun) { "Running (Sesuai Jadwal)" } else { "Deallocated (Sesuai Jadwal)" }
                    Send-Teams $vm.Name $state $sub.Id $tenant $vmLastTimeWIB
                }
            } catch {
                Write-Error "Gagal memproses VM '$($vmBasic.Name)' di Sub '$($sub.Id)': $_"
                Send-Teams $vmBasic.Name "ERROR: Gagal memproses ($_)" $sub.Id $tenant "N/A"
            }
        }
    } catch {
        Write-Error "Gagal memproses Subscription '$($sub.Id)': $_"
        Send-Teams "N/A" "ERROR Sub: $_" $sub.Id "Unknown" "N/A"
    }
}

# ===============================================================
# 5. MONITORING BACKGROUND JOBS & CLEANUP
# ===============================================================
if ($jobs.Count -gt 0) { 
    Write-Output "Menunggu $($jobs.Count) background job selesai..."
    $completedJobs = $jobs | Wait-Job -Timeout 300

    foreach ($j in $completedJobs) {
        Write-Output "Job ID $($j.Id) - State: $($j.State)"
        if ($j.State -eq "Failed") {
            $jobError = Receive-Job -Job $j 2>&1
            Write-Error "Background Job ID $($j.Id) gagal: $jobError"
        } elseif ($j.State -eq "Completed") {
            Receive-Job -Job $j 2>&1 | Out-Null
        }
    }
    $jobs | Remove-Job -Force 
}

Clear-AzContext -Scope Process -Force -ErrorAction SilentlyContinue
