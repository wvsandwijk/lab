[cmdletbinding()]
Param (
    $Configuration,
    [switch]$Remove,
    [switch]$Select
)

# Function to get a random number from a range excluding certain values
Function log() {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

function Get-RandomExcluding {
    param (
        [int]$Min,
        [int]$Max,
        [int[]]$Exclude
    )

    # Validate range
    if ($Min -gt $Max) {
        throw "Min value cannot be greater than Max value."
    }

    # Build the allowed list excluding specified numbers
    $allowed = $Min..$Max | Where-Object { $Exclude -notcontains $_ }

    if (-not $allowed) {
        throw "No numbers available after exclusions."
    }

    # Return a random number from the allowed list
    return Get-Random -InputObject $allowed
}

[xml]$ConfigurationData = Get-Content $Configuration
$VirtualMachines = $ConfigurationData.virtualmachines.virtualmachine

if ($Select) {
    $VMNames = $VirtualMachines
    $SelectedVMs = $VMNames | Out-GridView -Title "Select Virtual Machines to Process" -PassThru
    if (-not $SelectedVMs) {
        log -Message "No virtual machines selected. Exiting." -Level "WARNING"
        exit
    }
    $VirtualMachines = $selectedVMs
    log -Message "Selected virtual machines: $($VirtualMachines.Name -join ', ')" -Level "INFO"
}

foreach ($VM in $VirtualMachines) {
    if ($Remove) {
        if ((Get-vm $VM.name).State -ne 'stopped') {
            log -Message "Stopping VM: $($VM.Name)" -Level "INFO"
            Stop-VM $VM.name -TurnOff -Force
        }
        log -Message "Removing VM: $($VM.Name)" -Level "INFO"
        Remove-VM -Name $VM.Name -Force
        log -Message "Removing VM files for: $($VM.Name)" -Level "INFO"
        Remove-item $VM.vmpath -Recurse -Force
    } else {
        log -Message "Creating VM: $($VM.Name)" -Level "INFO"
        New-VM -Name $VM.Name -Generation 2 -MemoryStartupBytes 4096MB -SwitchName $VM.SwitchName -Path $VM.VMPath -NoVHD
        log -Message "Creating virtual disks for VM: $($VM.Name)" -Level "INFO"
        foreach ($disk in $VM.disks.disk) {
             $VHDPath = "$($VM.VMPath)\virtualdisk\$($disk.Name).vhdx"
             New-VHD -Path $VHDPath -SizeBytes ([int]$disk.SizeGB * 1GB) -BlockSizeBytes 1MB -Dynamic
             Add-VMHardDiskDrive -VMName $VM.Name -Path $VHDPath
        }
        log -Message "Configuring VM: $($VM.Name)" -Level "INFO"
        Set-VM -Name $VM.Name -ProcessorCount 2 -CheckpointType Production -AutomaticCheckpointsEnabled $false -SnapshotFileLocation "$($VM.VMPath)\Snapshot"
        log -Message "Adding CD-ROM drives to VM: $($VM.Name)" -Level "INFO"
        foreach ($cdrom in $VM.cdroms.cdrom) {
            $SCSIController = Get-VMScsiController -VMName $VM.Name
            log -Message "adding : $($cdrom.name)" -Level "INFO"
            $DVDLocation = (0..63 | Where-Object { $(($SCSIController).drives | Select-Object -ExpandProperty ControllerLocation) -notcontains $_ })[-1]
            Add-VMDvdDrive -VMName $VM.Name -Path $cdrom.ISO -ControllerNumber $SCSIController.ControllerNumber -ControllerLocation $DVDLocation -Verbose
        }
        if ($vm.vlan) {
            log -Message "Adding network adapters to VM: $($VM.Name)" -Level "INFO"
            set-VMNetworkAdapterVlan -VMName $VM.Name -Access -VlanId $vm.vlan
        }

        $DVDDrive = Get-VMDvdDrive -VMName $VM.Name | Sort-Object ControllerLocation -Descending | Select-Object -first 1
        log -Message "Setting firmware boot order for VM: $($VM.Name)" -Level "INFO"
        Set-VMFirmware -BootOrder $DVDDrive -VMName $VM.Name
        log -Message "Configuring secure boot for VM: $($VM.Name)" -Level "INFO"
        Set-VMKeyProtector -VMName $VM.Name -NewLocalKeyProtector
        log -Message "Enabling TPM for VM: $($VM.Name)" -Level "INFO"
        Enable-VMTPM -VMName $VM.Name
        log -Message "Starting VM: $($VM.Name)" -Level "INFO"
        Start-VM -Name $VM.Name
        log -Message "VM $($VM.Name) created and started successfully." -Level "INFO"
    }
}
