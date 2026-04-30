[cmdletbinding()]
param (
    [parameter(Mandatory = $true)]
    [string]$VMName,
    # [parameter(ParameterSetName='NewVM')]
    [string]$VHDPath = "C:\Hyper-V",
    # [parameter(ParameterSetName='NewVM')]
    [string]$ISOPath = "C:\ISO\w2025.iso",
    # [parameter(ParameterSetName='NewVM')]
    [string]$SwitchName = "vlan400",
    # [parameter(ParameterSetName='NewVM')]
    [int64]$MemoryStartupBytes = 2GB,
    # [parameter(ParameterSetName='NewVM')]
    [int64]$VHDSizeBytes = 127GB,
    # [parameter(ParameterSetName='NewVM')]    
    [int]$Generation = 2,
    [string]$ipaddress,
    [string]$subnet,    
    [string]$defaultgateway,
    [string]$dnsserver

)

#region ======= Functions =================
Function Set-VMNetworkConfiguration {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, Position=1, ParameterSetName='DHCP', ValueFromPipeline=$true)]
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Static', ValueFromPipeline=$true)]
        [Microsoft.HyperV.PowerShell.VMNetworkAdapter]$NetworkAdapter,

        [Parameter(Mandatory=$true, Position=1, ParameterSetName='Static')]
        [String[]]$IPAddress,

        [Parameter(Mandatory=$false, Position=2, ParameterSetName='Static')]
        [String[]]$Subnet,

        [Parameter(Mandatory=$false, Position=3, ParameterSetName='Static')]
        [String[]]$DefaultGateway ,

        [Parameter(Mandatory=$false, Position=4, ParameterSetName='Static')]
        [String[]]$DNSServer ,

        [Parameter(Mandatory=$false, Position=0, ParameterSetName='DHCP')]
        [Switch]$Dhcp
    )

    $VM = Get-WmiObject -Namespace 'root\virtualization\v2' -Class 'Msvm_ComputerSystem' | Where-Object { $_.ElementName -eq $NetworkAdapter.VMName } 
    $VMSettings = $vm.GetRelated('Msvm_VirtualSystemSettingData') | Where-Object { $_.VirtualSystemType -eq 'Microsoft:Hyper-V:System:Realized' }    
    $VMNetAdapters = $VMSettings.GetRelated('Msvm_SyntheticEthernetPortSettingData') 

    $NetworkSettings = @()
    foreach ($NetAdapter in $VMNetAdapters) {
        if ($NetAdapter.Address -eq $NetworkAdapter.MacAddress) {
            $NetworkSettings = $NetworkSettings + $NetAdapter.GetRelated("Msvm_GuestNetworkAdapterConfiguration")
        }
    }

    $NetworkSettings[0].IPAddresses = $IPAddress
    $NetworkSettings[0].Subnets = $Subnet
    $NetworkSettings[0].DefaultGateways = $DefaultGateway
    $NetworkSettings[0].DNSServers = $DNSServer
    $NetworkSettings[0].ProtocolIFType = 4096

    if ($dhcp) {
        $NetworkSettings[0].DHCPEnabled = $true
    } else {
        $NetworkSettings[0].DHCPEnabled = $false
    }

    $Service = Get-WmiObject -Class "Msvm_VirtualSystemManagementService" -Namespace "root\virtualization\v2"
    $setIP = $Service.SetGuestNetworkAdapterConfiguration($VM, $NetworkSettings[0].GetText(1))

    if ($setip.ReturnValue -eq 4096) {
        $job=[WMI]$setip.job 

        while ($job.JobState -eq 3 -or $job.JobState -eq 4) {
            start-sleep 1
            $job=[WMI]$setip.job
        }

        if ($job.JobState -eq 7) {
            write-host "Success"
        }
        else {
            $job.GetError()
        }
    } elseif($setip.ReturnValue -eq 0) {
        Write-Host "Success"
    }
}

#endregion ======= Functions =================

#region == Create the VM ================

$parameters = @{
    Name                = $VMName
    MemoryStartupBytes  = $MemoryStartupBytes
    Path                = "$VHDPath\$VMName"
    NewVHDPath          = "$VHDPath\$VMName\Virtual Hard Disks\$VMName-C.vhdx"
    NewVHDSizeBytes     = $VHDSizeBytes
    Generation          = $Generation
    SwitchName          = $SwitchName
}
New-VM @parameters

# === Add DVD Drive and set boot order ===
Add-VMDvdDrive -VMName $VMName -Path $ISOPath
Set-VMFirmware -VMName $VMName -BootOrder $(Get-VMDvdDrive -VMName $VMName), $(Get-VMHardDiskDrive -VMName $VMName)
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $False
#endregion == Create the VM ================

Pause 
Get-VM $VMName | Start-VM

#Start-sleep -seconds 120 -Verbose
#region == Set Static IP Address ================
#Get-VM $VMName | Get-VMNetworkAdapter | Set-VMNetworkConfiguration -IPAddress $ipaddress -Subnet $subnet -DefaultGateway $defaultgateway -DNSServer $dnsserver -Verbose

#endregion == Set Static IP Address ================

