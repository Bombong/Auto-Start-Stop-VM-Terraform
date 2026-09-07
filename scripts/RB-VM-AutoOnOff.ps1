# ===============================================================
# 1. ERROR HANDLER GLOBAL: Autentikasi & Inisialisasi Variabel
# ===============================================================
try {
    Connect-AzAccount -Identity -ErrorAction Stop | Out-Null

    $Webhook  = Get-AutomationVariable -Name 'TeamsWebhookURL'     -ErrorAction Stop
    $Mapping  = (Get-AutomationVariable -Name 'TenantMappingJSON'  -ErrorAction Stop) | ConvertFrom-Json
    $Includes = (Get-AutomationVariable -Name 'IncludedVMsJSON'    -ErrorAction Stop) | ConvertFrom-Json

} catch {
    Write-Error "CRITICAL: Gagal melakukan inisialisasi awal atau membaca variabel: $_"
    exit
}

$wibNow = [TimeZoneInfo]::ConvertTime((Get-Date), [TimeZoneInfo]::FindSystemTimeZoneById("SE Asia Standard Time"))
$isWork = ($wibNow.TimeOfDay -ge [TimeSpan]"08:30" -and $wibNow.TimeOfDay -lt [TimeSpan]"22:30")
$jobs   = [System.Collections.Generic.List[PSObject]]::new()

# ===============================================================
# 2. FUNCTION: Ambil Last Action Time dari Provisioning State
# ===============================================================
function Get-VMLastActionTime {
    param(
        [string] $ResourceGroupName,
        [string] $VMName
    )
    try {
        $vmDetail           = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status -ErrorAction Stop
        $provisioningStatus = $vmDetail.Statuses | Where-Object Code -like "ProvisioningState/*" | Select-Object -First 1

        if ($provisioningStatus -and $provisioningStatus.Time) {
            $tzWIB = [TimeZoneInfo]::FindSystemTimeZoneById("SE Asia Standard Time")
            return [TimeZoneInfo]::ConvertTime($provisioningStatus.Time, $tzWIB).ToString("dd-MM-yyyy HH:mm:ss")
        }

        return "Log tidak ditemukan"
    } catch {
        Write-Warning "Gagal ambil status VM '$VMName': $_"
        return "Gagal mengambil log"
    }
}

# ===============================================================
# 3. FUNCTION: Kirim Notifikasi Teams Adaptive Card
# ===============================================================
function Send-Teams {
    param(
        [string] $VMName,
        [string] $StatusText,
        [string] $SubscriptionId,
        [string] $TenantName,
        [string] $LastRunTime,
        [string] $PowerStateCode   # dioper eksplisit, bukan dari scope luar
    )

    $lastRunTimeText = if ($LastRunTime) { $LastRunTime } else { "N/A" }

    $lastTimeLabel = switch ($PowerStateCode) {
        "PowerState/running"     { "Last Start Time (WIB):"      }
        "PowerState/deallocated" { "Last Deallocate Time (WIB):" }
        default                  { "Last Status/Run Time (WIB):" }
    }

    $card = @{
        type        = "message"
        attachments = @(@{
            contentType = "application/vnd.microsoft.card.adaptive"
            content     = @{
                '$schema' = "http://adaptivecards.io/schemas/adaptive-card.json"
                type      = "AdaptiveCard"
                version   = "1.4"
                body      = @(
                    @{ type = "TextBlock"; size = "Medium"; weight = "Bolder"; text = "Azure Virtual Machine Status Update" },
                    @{ type = "FactSet"; facts = @(
                        @{ title = "Nama Tenant:";                    value = $TenantName         },
                        @{ title = "Subscription ID:";                value = $SubscriptionId     },
                        @{ title = "Nama Virtual Machine:";           value = $VMName             },
                        @{ title = "Status Virtual Machine:";         value = $StatusText         },
                        @{ title = $lastTimeLabel;                    value = $lastRunTimeText     },
                        @{ title = "Waktu Pengecekan Terakhir (WIB):"; value = $wibNow.ToString("dd-MM-yyyy HH:mm:ss") }
                    )}
                )
            }
        })
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-RestMethod -Uri $Webhook -Method Post -ContentType "application/json" -Body $card -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "Gagal kirim notifikasi Teams untuk '$VMName': $_"
    }
}

# ===============================================================
# 4. LOOP: Per-Subscription & Per-VM
# ===============================================================
foreach ($sub in Get-AzSubscription) {
    try {
        $ctx    = Set-AzContext -SubscriptionId $sub.Id -ErrorAction Stop
        $tenant = if ($Mapping.TenantName) { $Mapping.TenantName } else { $ctx.Tenant.Directory }
        $allVMs = Get-AzVM -ErrorAction Stop

        foreach ($vmBasic in $allVMs) {
            if (-not ($Includes | Where-Object { $vmBasic.Name -like $_ })) { continue }

            try {
                $vm          = Get-AzVM -ResourceGroupName $vmBasic.ResourceGroupName -Name $vmBasic.Name -Status -ErrorAction Stop
                $powerStatus = $vm.Statuses | Where-Object Code -like "PowerState*"
                $isRun       = $powerStatus.Code -eq "PowerState/running"
                $lastTime    = Get-VMLastActionTime -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name

                if ($isWork -and -not $isRun) {
                    $job = Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -AsJob -ErrorAction Stop
                    $jobs.Add($job)
                    Send-Teams -VMName $vm.Name -StatusText "Running (Proses Dinyalakan)" -SubscriptionId $sub.Id -TenantName $tenant -LastRunTime $lastTime -PowerStateCode $powerStatus.Code
                }
                elseif (-not $isWork -and $isRun) {
                    $job = Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force -AsJob -ErrorAction Stop
                    $jobs.Add($job)
                    Send-Teams -VMName $vm.Name -StatusText "Deallocated (Proses Dimatikan)" -SubscriptionId $sub.Id -TenantName $tenant -LastRunTime $lastTime -PowerStateCode $powerStatus.Code
                }
                else {
                    $state = if ($isRun) { "Running (Sesuai Jadwal)" } else { "Deallocated (Sesuai Jadwal)" }
                    Send-Teams -VMName $vm.Name -StatusText $state -SubscriptionId $sub.Id -TenantName $tenant -LastRunTime $lastTime -PowerStateCode $powerStatus.Code
                }
            } catch {
                Write-Error "Gagal memproses VM '$($vmBasic.Name)' di Sub '$($sub.Id)': $_"
                Send-Teams -VMName $vmBasic.Name -StatusText "ERROR: Gagal memproses ($_)" -SubscriptionId $sub.Id -TenantName $tenant -LastRunTime "N/A" -PowerStateCode ""
            }
        }
    } catch {
        Write-Error "Gagal memproses Subscription '$($sub.Id)': $_"
        Send-Teams -VMName "N/A" -StatusText "ERROR Sub: $_" -SubscriptionId $sub.Id -TenantName "Unknown" -LastRunTime "N/A" -PowerStateCode ""
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
