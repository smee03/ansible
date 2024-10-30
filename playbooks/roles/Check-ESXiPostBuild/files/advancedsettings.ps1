param (
    [string]$esxi_hostname
)

# Check if VMware PowerCLI module is installed, if not, install it
if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
    Install-Module -Name VMware.PowerCLI -Scope AllUsers -AllowClobber -Force
}
Import-Module -Name VMware.PowerCLI -ErrorAction Stop

# Connect to vCenter using the provided credentials from Jenkins environment variables
Connect-VIServer -Server $env:vcenter_hostname -User $env:vcenter_username -Password $env:vcenter_password -ErrorAction Stop

# Initialize the desired settings
$desiredSettings = @(
    "Config.HostAgent.log.level",
    "Annotations.WelcomeMessage",
    "Syslog.global.logHost",
    "Syslog.global.logDir",
    "Config.HostAgent.plugins.hostsvc.esxAdminsGroup",
    "VMFS3.GBLAllowMW",
    "LSOM.lsomEnableRebuildOnLSE",
    "VSAN.TrimDisksBeforeUseGranularity",
    "VMFS3.LFBCSlabSizeMaxMB",
    "UserVars.SuppressShellWarning",
    "Security.SshSessionLimit",
    "Security.AccountUnlockTime",
    "Security.PasswordQualityControl",
    "Security.AccountLockFailures",
    "Security.PasswordMaxDays",
    "Security.PasswordHistory",
    "DCUI.Access",
    "UserVars.DcuiTimeOut",
    "Net.DVFilterBindIpAddress",
    "Config.HostAgent.plugins.solo.enableMob",
    "Config.alert.log.outputToSyslog",
    "Config.alert.log.syslog.facility",
    "Config.alert.syslog.ident",
    "Config.alert.syslog.logHeaderFile",
    "Config.log.outputToSyslog",
    "Config.log.syslog.facility",
    "Config.log.syslog.ident",
    "Config.log.syslog.logHeaderfile",
    "Syslog.global.defaultRotate",
    "Syslog.global.defaultSize"
)

# Trim any whitespace from the hostname
$esxi_hostname = $esxi_hostname.Trim()

# Output current processing host
Write-Output "Processing ESXi host: $esxi_hostname"

# Get the specific ESXi host
$esxiHost = Get-VMHost -Name $esxi_hostname

if ($esxiHost) {
    # Retrieve advanced settings for the ESXi host
    $advancedSettings = Get-AdvancedSetting -Entity $esxiHost

    # Filter the advanced settings to include only the desired ones
    $filteredSettings = $advancedSettings | Where-Object { $desiredSettings -contains $_.Name }

    # Output the filtered settings
    if ($filteredSettings.Count -gt 0) {
        Write-Output "The ESXi host '$esxi_hostname' has the following advanced settings:"
        foreach ($setting in $filteredSettings) {
            Write-Output "HostName: $esxi_hostname"
            Write-Output "Name: $($setting.Name)"
            Write-Output "Value: $($setting.Value)"
            Write-Output ""
        }
    } else {
        Write-Output "The ESXi host '$esxi_hostname' has no matching advanced settings."
    }
} else {
    Write-Output "The ESXi host '$esxi_hostname' could not be found."
}

# Disconnect from the vCenter server
Disconnect-VIServer -Server $env:vcenter_hostname -Confirm:$false
