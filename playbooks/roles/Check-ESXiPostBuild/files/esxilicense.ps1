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

# Get the ServiceInstance object
$serviceInstance = Get-View ServiceInstance

# Get the License Manager reference and view
$LicManRef = $serviceInstance.Content.LicenseManager
$LicManView = Get-View $LicManRef

# Get the License Assignment Manager
$licAssMan = Get-View $LicManView.LicenseAssignmentManager

# Trim any whitespace from the hostname
$esxi_hostname = $esxi_hostname.Trim()

# Output current processing host
Write-Output "Processing ESXi host: $esxi_hostname"

# Get the specific ESXi host
$esxiHost = Get-VMHost -Name $esxi_hostname

if ($esxiHost) {
    # Extract licenses assigned to the specific ESXi host
    $licenses = $licAssMan.QueryAssignedLicenses($esxiHost.ExtensionData.MoRef.Value)

    # Check if any licenses are assigned to the ESXi host
    if ($licenses.Count -gt 0) {
        Write-Output "The ESXi host '$esxi_hostname' has the following licenses assigned:"
        foreach ($license in $licenses) {
            Write-Output "License Key: $($license.AssignedLicense.LicenseKey)"
            Write-Output "Product: $($license.AssignedLicense.Name)"
            Write-Output "Description: $($license.AssignedLicense.Description)"
        }
    } else {
        Write-Output "The ESXi host '$esxi_hostname' has no licenses assigned."
    }
} else {
    Write-Output "The ESXi host '$esxi_hostname' could not be found."
}

