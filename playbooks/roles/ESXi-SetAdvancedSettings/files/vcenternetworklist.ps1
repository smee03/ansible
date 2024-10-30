# Import the PowerCLI module
Import-Module VMware.PowerCLI

# Set PowerCLI configuration to ignore invalid certificates (optional, for self-signed certs)
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

# Define vCenter credentials and connection parameters
$vcenterServer = "ushvclp00007.tfayd.com"
$vcenterUsername = "206565366@tfayd.com"
$vcenterPassword = "26W;TyVaH#!e8u!E"

# Connect to vCenter
Connect-VIServer -Server $vcenterServer -User $vcenterUsername -Password $vcenterPassword

# Retrieve a list of networks
$networks = Get-View -ViewType Network

# Display the network names
$networkNames = $networks | ForEach-Object { $_.Name }
$networkNames

# Disconnect from vCenter
Disconnect-VIServer -Server $vcenterServer -Confirm:$false

