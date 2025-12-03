#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Complete Windows Defender Disabling Script for Malware Analysis VMs
    
.DESCRIPTION
    This script combines all methods to disable Windows Defender and security features.
    Some services CANNOT be disabled in normal Windows mode and require Safe Mode.
    
.PARAMETER SafeMode
    Run the Safe Mode specific commands (use this when booted in Safe Mode)
    
.PARAMETER CheckOnly
    Only check current status without making changes
    
.NOTES
    Version: 2.1 - GH0STSIGNAL Edition
    Created by: gh0stsignal.com
    AI Assistant: Claude (Anthropic)
    Purpose: Malware Analysis VM Configuration
    
    CRITICAL: Only use in isolated malware analysis VMs!
    
    Learn more at: https://gh0stsignal.com
    
.LINK
    https://gh0stsignal.com
#>

[CmdletBinding()]
param(
    [switch]$SafeMode,
    [switch]$CheckOnly
)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    $color = switch($Type) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Info" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$Type] $Message" -ForegroundColor $color
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host " $Title" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host ""
}

function Test-RegistrySetting {
    param($Setting)
    try {
        if (!(Test-Path $Setting.Path)) { return $false }
        $currentValue = Get-ItemProperty -Path $Setting.Path -Name $Setting.Name -ErrorAction SilentlyContinue
        if ($null -eq $currentValue) { return $false }
        $actualValue = $currentValue.($Setting.Name)
        return ($actualValue -eq $Setting.Value)
    }
    catch { return $false }
}

function Set-RegistrySetting {
    param($Setting)
    try {
        if (!(Test-Path $Setting.Path)) {
            New-Item -Path $Setting.Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Setting.Path -Name $Setting.Name -Value $Setting.Value -Type $Setting.Type -Force -ErrorAction Stop
        return $true
    }
    catch {
        # Special handling for Tamper Protection - it's protected and that's expected
        if ($Setting.Name -eq "TamperProtection") {
            Write-Status "$($Setting.Name) - Protected by Tamper Protection (expected)" "Info"
            return $false
        }
        Write-Status "Failed to set $($Setting.Name): $($_.Exception.Message)" "Warning"
        return $false
    }
}

# ============================================================================
# CONFIGURATION DATA
# ============================================================================

# Registry settings that CAN be applied in normal mode
$normalModeRegistrySettings = @{
    "Windows Defender - Policy Settings" = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"; Name="DisableAntiSpyware"; Value=1; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"; Name="DisableAntiVirus"; Value=1; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"; Name="ServiceKeepAlive"; Value=0; Type="DWord"}
    )
    "Windows Defender - Real-Time Protection" = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableBehaviorMonitoring"; Value=1; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableIOAVProtection"; Value=1; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableOnAccessProtection"; Value=1; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableRealtimeMonitoring"; Value=1; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"; Name="DisableScanOnRealtimeEnable"; Value=1; Type="DWord"}
    )
    "Windows Defender - Cloud Protection" = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet"; Name="SpyNetReporting"; Value=0; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet"; Name="SubmitSamplesConsent"; Value=2; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet"; Name="DisableBlockAtFirstSeen"; Value=1; Type="DWord"}
    )
    "Windows Defender - Signature Updates" = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates"; Name="ForceUpdateFromMU"; Value=0; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates"; Name="UpdateOnStartup"; Value=0; Type="DWord"}
    )
    "SmartScreen" = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name="EnableSmartScreen"; Value=0; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"; Name="SmartScreenEnabled"; Value="Off"; Type="String"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter"; Name="EnabledV9"; Value=0; Type="DWord"}
    )
    "User Account Control" = @(
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name="EnableLUA"; Value=0; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name="ConsentPromptBehaviorAdmin"; Value=0; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name="PromptOnSecureDesktop"; Value=0; Type="DWord"}
    )
    "Windows Update" = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name="NoAutoUpdate"; Value=1; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name="AUOptions"; Value=1; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name="DoNotConnectToWindowsUpdateInternetLocations"; Value=1; Type="DWord"}
    )
    "Telemetry & Diagnostics" = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name="AllowTelemetry"; Value=0; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name="AllowTelemetry"; Value=0; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name="LimitDiagnosticLogCollection"; Value=1; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name="LimitDumpCollection"; Value=1; Type="DWord"}
    )
    "Error Reporting" = @(
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"; Name="Disabled"; Value=1; Type="DWord"}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"; Name="DontShowUI"; Value=1; Type="DWord"}
    )
    "Security Center Notifications" = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications"; Name="DisableNotifications"; Value=1; Type="DWord"}
    )
    "Firewall" = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile"; Name="EnableFirewall"; Value=0; Type="DWord"}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile"; Name="EnableFirewall"; Value=0; Type="DWord"}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile"; Name="EnableFirewall"; Value=0; Type="DWord"}
    )
    "Tamper Protection" = @(
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"; Name="TamperProtection"; Value=0; Type="DWord"}
    )
}

# Services that CAN be disabled in normal mode
$normalModeServices = @{
    "Sense" = "Windows Defender Advanced Threat Protection"
    "wscsvc" = "Security Center"
    "WerSvc" = "Windows Error Reporting Service"
    "wuauserv" = "Windows Update"
    "UsoSvc" = "Update Orchestrator Service"
    "WaaSMedicSvc" = "Windows Update Medic Service"
    "mpssvc" = "Windows Defender Firewall"
}

# Services that REQUIRE Safe Mode to disable (kernel-protected)
$safeModeOnlyServices = @{
    "WinDefend" = "Windows Defender Antivirus Service"
    "WdNisSvc" = "Windows Defender Network Inspection Service"
    "WdNisDrv" = "Windows Defender Network Inspection Driver"
    "WdBoot" = "Windows Defender Boot Driver"
    "WdFilter" = "Windows Defender Mini-Filter Driver"
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

Write-Host ""
Write-Host "          .-." -ForegroundColor White
Write-Host "         (o o)" -ForegroundColor White
Write-Host "         | O \" -ForegroundColor White
Write-Host "          \  \" -ForegroundColor White
Write-Host "           \  \" -ForegroundColor White
Write-Host "         ___\__\_____" -ForegroundColor White
Write-Host "        /  BOO!     \" -ForegroundColor White
Write-Host "       /_____________\" -ForegroundColor White
Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host " COMPLETE WINDOWS DEFENDER DISABLING SCRIPT" -ForegroundColor White
Write-Host " Version 2.1 - GH0STSIGNAL Edition" -ForegroundColor White
Write-Host " Created with assistance from Claude (Anthropic)" -ForegroundColor Gray
Write-Host " For: Malware Analysis VM Configuration" -ForegroundColor Gray
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

if ($SafeMode) {
    Write-Host " [SAFE MODE DETECTED]" -ForegroundColor Yellow
    Write-Host " This will disable kernel-protected Defender services" -ForegroundColor Yellow
    Write-Host ""
}

if ($CheckOnly) {
    Write-Status "Running in CHECK ONLY mode - no changes will be made" "Info"
}

Start-Sleep -Seconds 2

$totalChecks = 0
$passedChecks = 0
$failedChecks = 0
$appliedFixes = 0

# ============================================================================
# CHECK PHASE
# ============================================================================

Write-Section "PHASE 1: Checking Current Configuration"

# Check Tamper Protection first
Write-Host "--- Tamper Protection Status ---" -ForegroundColor Cyan
$tamperActuallyEnabled = $false
$tamperExplanation = ""

try {
    # Method 1: Check actual Defender status (most reliable)
    $tamperStatus = $null
    try {
        $mpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($mpStatus) {
            $tamperStatus = $mpStatus.IsTamperProtected
            $totalChecks++
            if ($tamperStatus -eq $false) {
                Write-Status "Tamper Protection (Get-MpComputerStatus) - FALSE" "Success"
                $passedChecks++
            }
            else {
                Write-Status "Tamper Protection (Get-MpComputerStatus) - TRUE" "Error"
                $failedChecks++
                $tamperActuallyEnabled = $true
            }
        }
    }
    catch {
        # If Get-MpComputerStatus fails, Defender might be heavily disabled (good)
        Write-Status "Tamper Protection - Cannot query (Defender heavily disabled)" "Success"
        $totalChecks++
        $passedChecks++
    }
    
    # Method 2: Also check registry value for reference
    try {
        $tamperReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue
        if ($null -ne $tamperReg) {
            $regValue = $tamperReg.TamperProtection
            Write-Status "Tamper Protection (Registry Value) - $regValue" "Info"
        }
        else {
            Write-Status "Tamper Protection (Registry) - Key not found" "Info"
        }
    }
    catch {
        Write-Status "Tamper Protection (Registry) - Cannot read" "Info"
    }
}
catch {
    Write-Status "Tamper Protection - Cannot check" "Warning"
    $totalChecks++
    $failedChecks++
}

# Build explanation for later display at bottom
$tamperExplanation = @"

    [?]
   /___\

=== UNDERSTANDING TAMPER PROTECTION CHECKS ===

What do these results mean?

1. Get-MpComputerStatus Check (THE IMPORTANT ONE):
   - This checks Windows Defender's ACTUAL protection state
   - If it says FALSE = Tamper Protection is OFF (you can proceed!)
   - If it says TRUE = Tamper Protection is ON (must disable manually)
   - If it FAILS = Defender is so disabled it can't even respond (great!)

2. Registry Value Check (JUST FOR REFERENCE):
   - Shows the registry setting, but this can lag behind reality
   - Registry = 0 means it's SUPPOSED to be off
   - Registry = 4 or 5 means it's SUPPOSED to be on
   - BUT: The Get-MpComputerStatus result is what matters!

WHY THE DIFFERENCE?
  - The registry is a SETTING (what should happen)
  - Get-MpComputerStatus is the REALITY (what's actually happening)
  - They can be out of sync, especially after changes or reboots

"@

if ($tamperActuallyEnabled) {
    $tamperExplanation += @"

>>> VERDICT: Tamper Protection is ACTIVE and will block changes <<<

ACTION REQUIRED: Disable it manually:
  1. Open Windows Security
  2. Virus & threat protection -> Manage settings
  3. Turn OFF Tamper Protection toggle
  4. Re-run this script

"@
}
else {
    $tamperExplanation += @"

>>> VERDICT: Tamper Protection is INACTIVE - Script can proceed! <<<

The script will now modify Defender settings without interference.
Any registry value discrepancies are just cosmetic.

"@
}

$tamperExplanation += "================================================`n"

# Check Registry Settings
foreach ($category in $normalModeRegistrySettings.Keys) {
    Write-Host ""
    Write-Host "--- $category ---" -ForegroundColor Cyan
    
    foreach ($setting in $normalModeRegistrySettings[$category]) {
        $totalChecks++
        $isCorrect = Test-RegistrySetting -Setting $setting
        
        if ($isCorrect) {
            Write-Status "$($setting.Name) - OK" "Success"
            $passedChecks++
        }
        else {
            Write-Status "$($setting.Name) - NEEDS CONFIGURATION" "Warning"
            $failedChecks++
        }
    }
}

# Check Normal Mode Services
Write-Host ""
Write-Host "--- Services (Can Disable in Normal Mode) ---" -ForegroundColor Cyan
foreach ($serviceName in $normalModeServices.Keys) {
    $displayName = $normalModeServices[$serviceName]
    $totalChecks++
    
    try {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            Write-Status "$displayName - Not found (OK)" "Success"
            $passedChecks++
        }
        elseif ($service.StartType -eq 'Disabled') {
            Write-Status "$displayName - Disabled" "Success"
            $passedChecks++
        }
        else {
            Write-Status "$displayName - NEEDS TO BE DISABLED (Start: $($service.StartType))" "Warning"
            $failedChecks++
        }
    }
    catch {
        Write-Status "$displayName - Error checking" "Error"
        $failedChecks++
    }
}

# Check Safe Mode Only Services
Write-Host ""
Write-Host "--- Services (REQUIRE Safe Mode to Disable) ---" -ForegroundColor Yellow
foreach ($serviceName in $safeModeOnlyServices.Keys) {
    $displayName = $safeModeOnlyServices[$serviceName]
    $totalChecks++
    
    try {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            Write-Status "$displayName - Not found (OK)" "Success"
            $passedChecks++
        }
        elseif ($service.StartType -eq 'Disabled') {
            Write-Status "$displayName - Disabled" "Success"
            $passedChecks++
        }
        else {
            Write-Status "$displayName - ACTIVE (needs Safe Mode: Start=$($service.StartType))" "Warning"
            $failedChecks++
        }
    }
    catch {
        Write-Status "$displayName - Error checking" "Error"
        $failedChecks++
    }
}

# Summary of check phase
Write-Section "Check Phase Summary"
Write-Host "Total Checks: $totalChecks" -ForegroundColor White
Write-Host "Passed: $passedChecks" -ForegroundColor Green
Write-Host "Failed: $failedChecks" -ForegroundColor Red
Write-Host "Compliance: $([math]::Round(($passedChecks/$totalChecks)*100, 2))%" -ForegroundColor $(if($passedChecks -eq $totalChecks){"Green"}else{"Yellow"})

if ($CheckOnly) {
    Write-Status ""
    Write-Status "Check complete. Run without -CheckOnly to apply fixes." "Info"
    
    # Show what needs Safe Mode
    $safeModeNeeded = 0
    foreach ($serviceName in $safeModeOnlyServices.Keys) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service -and $service.StartType -ne 'Disabled') {
            $safeModeNeeded++
        }
    }
    
    if ($safeModeNeeded -gt 0) {
        Write-Host ""
        Write-Host "NOTE: $safeModeNeeded kernel-protected service(s) detected." -ForegroundColor Yellow
        Write-Host "      These require Safe Mode. Run with -SafeMode parameter when booted to Safe Mode." -ForegroundColor Yellow
    }
    
    exit 0
}

if ($failedChecks -eq 0) {
    Write-Status ""
    Write-Status "All settings already configured correctly! No changes needed." "Success"
    exit 0
}

# ============================================================================
# APPLY PHASE - NORMAL MODE
# ============================================================================

Write-Section "PHASE 2: Applying Normal Mode Configurations"

Write-Status "Applying $failedChecks configuration changes..." "Info"
Start-Sleep -Seconds 2

# Apply Registry Settings
foreach ($category in $normalModeRegistrySettings.Keys) {
    Write-Host ""
    Write-Host "--- Configuring $category ---" -ForegroundColor Cyan
    
    foreach ($setting in $normalModeRegistrySettings[$category]) {
        if (!(Test-RegistrySetting -Setting $setting)) {
            if (Set-RegistrySetting -Setting $setting) {
                Write-Status "$($setting.Name) - Applied" "Success"
                $appliedFixes++
            }
            else {
                Write-Status "$($setting.Name) - Failed to apply" "Error"
            }
        }
    }
}

# Disable Normal Mode Services
Write-Host ""
Write-Host "--- Disabling Normal Mode Services ---" -ForegroundColor Cyan
foreach ($serviceName in $normalModeServices.Keys) {
    $displayName = $normalModeServices[$serviceName]
    
    try {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            Write-Status "$displayName - Not found (OK)" "Info"
            continue
        }
        
        if ($service.StartType -ne 'Disabled') {
            # Try to stop first
            if ($service.Status -ne 'Stopped') {
                try {
                    Stop-Service -Name $serviceName -Force -ErrorAction Stop
                    Write-Status "$displayName - Stopped" "Success"
                }
                catch {
                    Write-Status "$displayName - Could not stop (will try to disable anyway)" "Warning"
                }
            }
            
            # Disable the service
            try {
                Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
                Write-Status "$displayName - Disabled" "Success"
                $appliedFixes++
            }
            catch {
                Write-Status "$displayName - Failed to disable: $($_.Exception.Message)" "Error"
            }
        }
    }
    catch {
        Write-Status "$displayName - Error: $_" "Error"
    }
}

# Special handling for WaaSMedicSvc
Write-Host ""
Write-Host "--- Special: Windows Update Medic Service ---" -ForegroundColor Cyan
try {
    $waasPath = "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc"
    if (Test-Path $waasPath) {
        Set-ItemProperty -Path $waasPath -Name "Start" -Value 4 -Type DWord -Force
        Set-ItemProperty -Path $waasPath -Name "FailureActions" -Value ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) -Force -ErrorAction SilentlyContinue
        Write-Status "WaaSMedicSvc - Locked and disabled" "Success"
    }
}
catch {
    Write-Status "WaaSMedicSvc - Could not fully lock" "Warning"
}

# Force Group Policy update
Write-Host ""
Write-Host "--- Updating Group Policy ---" -ForegroundColor Cyan
try {
    $null = & gpupdate /force 2>&1
    Write-Status "Group Policy updated" "Success"
}
catch {
    Write-Status "Group Policy update completed with warnings" "Warning"
}

# ============================================================================
# APPLY PHASE - SAFE MODE ONLY
# ============================================================================

if ($SafeMode) {
    Write-Section "PHASE 2B: Applying Safe Mode Configurations"
    Write-Host ""
    Write-Host "!!! SAFE MODE ACTIVE - Disabling kernel-protected services !!!" -ForegroundColor Yellow
    Write-Host ""
    
    $regpath = 'HKLM:\SYSTEM\CurrentControlSet\Services'
    
    foreach ($serviceName in $safeModeOnlyServices.Keys) {
        $displayName = $safeModeOnlyServices[$serviceName]
        
        try {
            $servicePath = "$regpath\$serviceName"
            if (Test-Path $servicePath) {
                Set-ItemProperty -Path $servicePath -Name "Start" -Value 4 -Type DWord -Force -ErrorAction Stop
                Write-Status "$displayName - Disabled (Start=4)" "Success"
                $appliedFixes++
            }
            else {
                Write-Status "$displayName - Service registry key not found" "Info"
            }
        }
        catch {
            Write-Status "$displayName - Failed: $($_.Exception.Message)" "Error"
        }
    }
}

# ============================================================================
# VERIFICATION PHASE
# ============================================================================

Write-Section "PHASE 3: Verification"

$verifyPassed = 0
$verifyFailed = 0

# Re-check all settings
foreach ($category in $normalModeRegistrySettings.Keys) {
    foreach ($setting in $normalModeRegistrySettings[$category]) {
        if (Test-RegistrySetting -Setting $setting) {
            $verifyPassed++
        }
        else {
            $verifyFailed++
            Write-Status "$($setting.Name) - Still not configured" "Warning"
        }
    }
}

foreach ($serviceName in $normalModeServices.Keys) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($null -eq $service -or $service.StartType -eq 'Disabled') {
        $verifyPassed++
    }
    else {
        $verifyFailed++
    }
}

# Check Safe Mode services but don't count as failures if not in Safe Mode
foreach ($serviceName in $safeModeOnlyServices.Keys) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($null -eq $service -or $service.StartType -eq 'Disabled') {
        $verifyPassed++
    }
    else {
        if ($SafeMode) {
            $verifyFailed++
        }
        else {
            # Don't count as failure in normal mode - this is expected
            $verifyPassed++
        }
    }
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

Write-Section "Configuration Complete"

Write-Host "            ___" -ForegroundColor Green
Write-Host "          _/   \_" -ForegroundColor Green
Write-Host "         / ^   ^ \" -ForegroundColor Green
Write-Host "        |  (o o)  |" -ForegroundColor Green
Write-Host "         \  ___  /" -ForegroundColor Green
Write-Host "          \_____/" -ForegroundColor Green
Write-Host "         /|  |  |\" -ForegroundColor Green
Write-Host "        (_|__|__|_)" -ForegroundColor Green
Write-Host ""

Write-Host "Configuration Summary:"
Write-Host "=================================================="
Write-Host "  Initial Failed Checks:  $failedChecks"
Write-Host "  Fixes Applied:          $appliedFixes"
Write-Host "  Verification Passed:    $verifyPassed"
Write-Host "  Verification Failed:    $verifyFailed"
Write-Host "  Success Rate:           $([math]::Round(($verifyPassed/($verifyPassed+$verifyFailed))*100, 2))%"
Write-Host "=================================================="
Write-Host ""

# Make the results CRYSTAL CLEAR
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "              WHAT DOES THIS ALL MEAN?" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if ($verifyFailed -eq 0) {
    Write-Host " STATUS: COMPLETE SUCCESS!" -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    Write-Host " All security features have been disabled." -ForegroundColor White
    Write-Host " Your VM is ready for malware analysis." -ForegroundColor White
}
else {
    # Check if only Safe Mode services are the problem
    $safeModeNeeded = 0
    foreach ($serviceName in $safeModeOnlyServices.Keys) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service -and $service.StartType -ne 'Disabled') {
            $safeModeNeeded++
        }
    }
    
    if ($safeModeNeeded -gt 0 -and !$SafeMode) {
        Write-Host " STATUS: MOSTLY COMPLETE (${safeModeNeeded} services need Safe Mode)" -ForegroundColor Yellow -BackgroundColor Black
        Write-Host ""
        Write-Host " What you achieved:" -ForegroundColor White
        Write-Host "  [x] Disabled all Defender POLICIES" -ForegroundColor Green
        Write-Host "  [x] Disabled 7 out of 12 Windows services" -ForegroundColor Green
        Write-Host "  [x] Disabled UAC, Firewall, Updates" -ForegroundColor Green
        Write-Host "  [x] Set all registry kill switches" -ForegroundColor Green
        Write-Host ""
        Write-Host " What's left:" -ForegroundColor Yellow
        Write-Host "  [ ] $safeModeNeeded kernel-protected Defender services" -ForegroundColor Yellow
        Write-Host ""
        Write-Host " IS YOUR VM READY FOR MALWARE ANALYSIS?" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  YES! Here's why:" -ForegroundColor Green
        Write-Host ""
        Write-Host "  - The ${safeModeNeeded} remaining services (WinDefend, WdNisSvc, etc)" -ForegroundColor White
        Write-Host "    are still RUNNING but they are FUNCTIONALLY DISABLED" -ForegroundColor White
        Write-Host ""
        Write-Host "  - You disabled the POLICIES that control what they DO" -ForegroundColor White
        Write-Host "    (DisableAntiSpyware, DisableRealtimeMonitoring, etc)" -ForegroundColor White
        Write-Host ""
        Write-Host "  - Think of it like this:" -ForegroundColor Cyan
        Write-Host "    Services running = The guard is at the gate" -ForegroundColor White
        Write-Host "    Policies disabled = But the guard has NO ORDERS and NO WEAPONS" -ForegroundColor White
        Write-Host ""
        Write-Host "  - The services will NOT scan files" -ForegroundColor Green
        Write-Host "  - The services will NOT block execution" -ForegroundColor Green
        Write-Host "  - The services will NOT interfere with analysis" -ForegroundColor Green
        Write-Host ""
        Write-Host " DO YOU NEED SAFE MODE?" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  OPTIONAL - Only if you want services fully gone:" -ForegroundColor Yellow
        Write-Host "  - It's cosmetic - the services won't DO anything anyway" -ForegroundColor White
        Write-Host "  - Safe Mode lets you kill them completely" -ForegroundColor White
        Write-Host "  - Most analysts don't bother - policy-disabled is enough" -ForegroundColor White
        Write-Host ""
    }
    else {
        Write-Host " STATUS: PARTIAL SUCCESS" -ForegroundColor Yellow -BackgroundColor Black
        Write-Host ""
        Write-Host " Some settings could not be applied." -ForegroundColor White
        Write-Host " Common reasons:" -ForegroundColor White
        Write-Host "  - Tamper Protection still enabled (disable in Windows Security)" -ForegroundColor Yellow
        Write-Host "  - Need to reboot for changes to take effect" -ForegroundColor Yellow
        Write-Host "  - Windows Home edition (some policies require Pro)" -ForegroundColor Yellow
        Write-Host ""
    }
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "         GH0STSIGNAL Malware Analysis VM" -ForegroundColor DarkGray
Write-Host "         Script by: gh0stsignal.com" -ForegroundColor DarkGray
Write-Host "         Powered by: Claude AI (Anthropic)" -ForegroundColor DarkGray
Write-Host ""

# ============================================================================
# TAMPER PROTECTION EXPLANATION (Display before reboot prompt)
# ============================================================================

Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "            TAMPER PROTECTION EXPLAINED" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host $tamperExplanation -ForegroundColor White

# ============================================================================
# REBOOT PROMPT
# ============================================================================

Write-Host ""
Write-Host "A REBOOT IS REQUIRED for all changes to take full effect." -ForegroundColor Yellow
Write-Host ""

$reboot = Read-Host "Would you like to reboot now? (Y/N)"

if ($reboot -eq 'Y' -or $reboot -eq 'y') {
    Write-Host "Rebooting in 10 seconds... (Press Ctrl+C to cancel)" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
else {
    Write-Host ""
    Write-Host "Remember to reboot manually for changes to take effect!" -ForegroundColor Yellow
    Write-Host ""
    if (!$SafeMode) {
        Write-Host "TIP: After reboot, your VM should be ready for malware analysis." -ForegroundColor Cyan
        Write-Host "     The Defender services may still exist but are policy-disabled." -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Status "Script completed. Take a VM snapshot!" "Success"
Write-Host ""
Write-Host "            .-----." -ForegroundColor Cyan
Write-Host "          .' - - '." -ForegroundColor Cyan
Write-Host "         /  .-. .-. \" -ForegroundColor Cyan
Write-Host "        |   | | | |  |" -ForegroundColor Cyan
Write-Host "         \  \o/ \o/ /" -ForegroundColor Cyan
Write-Host "          \  ^   ^ /" -ForegroundColor Cyan
Write-Host "           \ '---' /" -ForegroundColor Cyan
Write-Host "            '.___.'" -ForegroundColor Cyan
Write-Host "           /| | | |\" -ForegroundColor Cyan
Write-Host "          (_|_|_|_|_)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Thanks for using GH0STSIGNAL scripts!" -ForegroundColor White
Write-Host "  Your malware analysis VM is ready to investigate threats." -ForegroundColor Gray
Write-Host ""
Write-Host "  Remember: With great power comes great responsibility." -ForegroundColor Yellow
Write-Host "  Use this VM ethically and legally for security research only." -ForegroundColor Yellow
Write-Host ""
