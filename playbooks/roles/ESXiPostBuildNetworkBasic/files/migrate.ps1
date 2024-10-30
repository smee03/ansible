############################################

Function Move-HostAndVMsFromvSS
{
    <#
        .SYNOPSIS
          This cmdlet Moves Host from Standard switch to distributed switch.
        
        .DESCRIPTION
          This cmdlet Moves Host from Standard switch to distributed switch.
    #>

    [CmdletBinding()]
    Param (
	    [Parameter(Mandatory=$true,HelpMessage="Distributed Switch")]
        [ValidateNotNullOrEmpty()]
	    $vDSwitch
        ,
        [Parameter(Mandatory=$false,HelpMessage="Standard Switch Network Port Prefix")]
	    [string]$vSwitchPGPrefix
        ,
        [Parameter(Mandatory=$true,HelpMessage="ESX Host Details & Uplinks to Move")]
        [ValidateNotNullOrEmpty()]
	    [array]$esxHostsParameters
        ,
        [Parameter(Mandatory=$true,HelpMessage="Source VI connection")]
	    [VMware.VimAutomation.ViCore.Util10.VersionedObjectImpl]$SourceVC
    )

    # Loop through each host and move
    Foreach($esxHostParameters in $esxHostsParameters)
    {
        $SkipHostMove = $esxHostParameters.SkipHostMove
        $esxHost = $esxHostParameters.esxHost
        $MoveLastUplink = $false

        if ($SkipHostMove -eq $false)
        {
            Write-Host " "  -ForegroundColor Green    
            Write-Host "----------------------------------------------------"  -ForegroundColor Green
            Write-Host "-- Starting move for host $($esxHost) " -ForegroundColor Green
            
            $MoveAllUplinks = $esxHostParameters.MoveAllUplinks
            $MoveVMs = $esxHostParameters.MoveVMs
            $uplinksToMove = $esxHostParameters.uplinksToMove
            $vSSwitch = $esxHostParameters.vSSwitch
        
            # Get Physical & Kernal Nics
            $hostPhysicalNics = $vSSwitch | Get-VMHostNetworkAdapter -VMHost $esxHost -Physical -Server $SourceVC 
            $hostVMKernalNics = $vSSwitch | Get-VMHostNetworkAdapter -VMHost $esxHost -VMKernel -Server $SourceVC 
            
            if ($hostPhysicalNics.Count -eq 0)
            {
                Write-Host "-- No Physical Nic found on standard switch $($vSSwitch) for host $($esxHost)" -ForegroundColor Yellow
            }

            # verify if the host is not part of Distributed switch first
            $vdsHost = Get-VMHost -Name $esxHost.Name -DistributedSwitch $vDSwitch -Server $SourceVC -ErrorAction SilentlyContinue
            
            if ($vdsHost -eq $null)
            {
                # Add ESXi host to VDS
                Write-Host "-- Adding $($esxHost) to $($vDSwitch)" -ForegroundColor Green
                $vDSwitch | Add-VDSwitchVMHost -VMHost $esxHost -Server $SourceVC -ErrorAction Stop | Out-Null
            }
            else
            {
                Write-Host "-- Host is already part of '$($vDSwitch)' switch" -ForegroundColor Yellow
            }         
            
            # Get pNIC from Host for VDSwitch
            #$vdsHostPhysicalNics = $vDSwitch | Get-VMHostNetworkAdapter -VMHost $esxHost -Physical -Server $SourceVC

            # Preaper VMKernal & Port Groups to Move
            $vDPortGroups = @()
            Write-Host "-- Preparing VMKenal & Portgroups to migrate" -ForegroundColor Green
            if ($hostVMKernalNics.Count -gt 0)
            {
                Foreach ($hostKernalNic in $hostVMKernalNics)
                {
                    # Get standard portgroup and vlan details of Kernal port
                    $vPortGroupName = $hostKernalNic.PortGroupName 
                    $vSPortGroup = $vSSwitch | Get-VirtualPortGroup -Name $vPortGroupName -Standard -Server $SourceVC 
                    $vSPortGroupVlanId = $vSPortGroup.VlanConfiguration.VlanId

                    # Set to 0 if no vLAN 
                    If ($vSPortGroupVlanId -eq $null)
                    {
                        $vSPortGroupVlanId = 0
                    }

                    # Check if port already exist,
                    # if not create new portgroup on distributed switch
                    $vDPortGroup = Get-VDPortgroup $vPortGroupName -VDSwitch $vDSwitch -Server $SourceVC -ErrorAction SilentlyContinue
                    If ($vDPortGroup -eq $null)
                    {
                        Write-Host "-- VMKernal Portgroup '$vPortGroupName' not found on distributed switch" -ForegroundColor Green
                        Write-Host "-- Creating Portgroup '$vPortGroupName' on distributed switch with vLAN id '$vSPortGroupVlanId'" -ForegroundColor Green
                        $vDPortGroup =  New-VDPortgroup -Name $vPortGroupName -VLanId $vSPortGroupVlanId -VDSwitch $vDSwitch -Server $SourceVC # -ErrorAction SilentlyContinue -ErrorVariable ErrorMessage
                        Check-Errors($ErrorMessage) | Out-Null 
                    }

                    # Add to Portgroup array      
                    $vDPortGroups += $vDPortGroup        
                }
            }
            else 
            {
                Write-Host "-- No VMKernal Ports found to migrate on standard switch $($vSSwitch) for host $($esxHost)" -ForegroundColor Yellow
            }
            
            # If moving only selected pNIC then Move all at once,
            # If moving all pNIC then move half first, 
            # then move VMs then move other to avoid VMs network disconnect
            $uplinkToMove =  @()

            if ($MoveAllUplinks -eq $true) 
            {
                # if moving all uplinks then divide into half to move in two steps 
                $totalUplinks = $hostPhysicalNics.Count
                #Write-Host "Total Uplink on Standard Switch - $totalUplinks"
                
                # if only one nic left moving that, otherwise prepare list of half nics to move
                if($totalUplinks -eq 1) 
                { 
                    $uplinkToMove = $hostPhysicalNics 
                    $totalUplinksToMove = 0
                }
                else 
                {
                    $totalUplinksToMove = [math]::Round($totalUplinks/2)
                    For($index = 0; $index -lt $totalUplinksToMove; $index++)
                    {
                        $uplinkToMove += $hostPhysicalNics[$index]
                    }
                }
            }
            else
            {
                $uplinkToMove =  $uplinksToMove
            }

            # Prepare Inputs to Migrate pNIC to VDS           
            $allInputs = @{
                VMHostPhysicalNic = $uplinkToMove
                DistributedSwitch = $vDSwitch
                Server = $SourceVC
                Confirm = $false
            }

            # Set VMKernal & Portgroups to move 
            if ($hostVMKernalNics.Count -gt 0)
            {
                $allInputs.VMHostVirtualNic = $hostVMKernalNics
                $allInputs.VirtualNicPortgroup = $vDPortGroups
            }

            # only one pNIC left move pNIC after VM move 
            if ($hostPhysicalNics.Count -eq 1 -and $MoveAllUplinks -eq $true)
            {
                Write-Host "-- Only '$($hostPhysicalNics)' on Standard Switch, Uplink will move after VMs move" -ForegroundColor Green     
                $MoveLastUplink = $true     
            }
            else 
            {
                Write-Host "-- Moving Physical Nic '$($uplinkToMove)' , VMKernal & PortGroups to Distributed Switch" -ForegroundColor Green          
                Add-VDSwitchPhysicalNetworkAdapter @allInputs    
            }
            
            # Move VMs
            If ($MoveVMs -eq $true)
            {
                Move-VMsFromvSSTovDS -vDSwitch $vDSwitch -vSwitchPGPrefix $vSwitchPGPrefix -esxHosts @($esxHosts) -SourceVC $SourceVC
            }

            # Move last pNIC with vMKernals ports
            if($MoveLastUplink -eq $true)
            {
                Write-Host "-- Moving remaining Uplinks $($uplinkToMove)" -ForegroundColor Green
                # Move pNics & VMKernals to Distributed switch
                Add-VDSwitchPhysicalNetworkAdapter @allInputs  

            } # Move remaining pNIC if any left 
            elseif ($MoveAllUplinks -eq $true) 
            {
                # Only one uplink
                if($hostPhysicalNics.Count -eq 1) 
                { 
                    $uplinkToMove += $hostPhysicalNics
                }
                else
                {
                    # get remaining uplinks
                    $uplinkToMove = @()
                    For($index = $totalUplinksToMove; $index -lt $totalUplinks; $index++)
                    {
                        $uplinkToMove += $hostPhysicalNics[$index]
                    }
                }

                Write-Host "-- Moving remaining Uplinks $($uplinkToMove)" -ForegroundColor Green
                # Move pNics to Distributed switch
                Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $vDSwitch -VMHostPhysicalNic $uplinkToMove -Server $SourceVC -Confirm:$false
            }
        }
        else 
        {
            Write-Host "-- Host $($esxHost) is set to skipped for move" -ForegroundColor Yellow   
        }
    } # end foreach 
  Write-Host "-- Finish moving Host from Standard switch to Distributed" -ForegroundColor Green
}
