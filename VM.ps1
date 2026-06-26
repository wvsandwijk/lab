<#
.SYNOPSIS
    This script creates or removes virtual machines based on a provided XML configuration file. It checks for necessary permissions, allows for selecting specific VMs to process, and logs actions taken during execution.
.DESCRIPTION
    The script reads an XML configuration file that defines virtual machines, their disk configurations, CD-ROM drives, and network settings. It can either create new VMs based on this configuration or remove existing VMs and their associated files. The script also includes logging functionality to track its actions.
.EXAMPLE
    .\VM.ps1 -Configuration "C:\Path\To\Config.xml"
    This command will create virtual machines as defined in the specified XML configuration file.
.EXAMPLE
    .\VM.ps1 -Configuration "C:\Path\To\Config.xml" -Remove -Select
    This command will allow you to select which virtual machines to remove based on the provided XML configuration file.
.EXAMPLE
    .\VM.ps1 -Configuration "C:\Path\To\Config.xml" -Select
    This command will allow you to select which virtual machines to create based on the provided XML configuration file.
.PARAMETER Configuration
    The path to the XML configuration file that defines the virtual machines to be created or removed.  This parameter is mandatory.
.PARAMETER Remove
    A switch parameter that indicates whether to remove the virtual machines defined in the configuration file. If not specified, the script will create the virtual machines instead.
.PARAMETER Select
    A switch parameter that allows the user to select specific virtual machines to process (either create or remove) from the list defined in the configuration file. If not specified, all virtual machines in the configuration will be processed.
.PARAMETER Path
    A dynamic parameter that specifies the path to the XML configuration file. This parameter is mandatory and includes validation to ensure the file exists.
.NOTES
    Created by Wessel van Sandwijk on 2026-06-19. This script is intended for use in a lab environment and should be run with appropriate permissions.


#>
[cmdletbinding()]
Param (
    [parameter(Mandatory = $true)]
    [string]$Configuration = ".\config.xml",
    [switch]$Remove,
    [switch]$Select
)

begin {
    # Check groupmembership
    $groupmembership = whoami /groups /fo csv | Convertfrom-csv
    Switch ($groupmembership.'Group Name') {
        "BUILTIN\Administrators" { $isadmin = $true }
        "BUILTIN\Hyper-V Administrators" { $ishypervadmin = $true }
    }
    if (-not $isadmin -and -not $ishypervadmin) {
        Write-Host "You must be a member of the Administrators or Hyper-V Administrators group to run this script." -ForegroundColor Red
        exit
    }

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

}
process {
    if ($Select) {

        if ($remove) {
            $installedvms = Get-VM
            log -Message "Fetching running VMs" -Level "INFO"
            $VMNames = foreach ($runningvm in $installedvms) {
                if ($VirtualMachines.name -contains $runningvm.name) { $runningvm }
            }
        }
        else {
            $VMNames = $VirtualMachines
        }

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
            log -Message "Removing VM files for: $($VM.Name) ($($VM.Path))" -Level "INFO"
            Remove-item $VM.Path -Recurse -Force
            log -Message "VM $($VM.Name) and associated files removed successfully." -Level "INFO"
        }
        else {
        #Create the VM
            log -Message "Creating VM: $($VM.Name)" -Level "INFO"
            $newvm = New-VM -Name $VM.Name -Generation 2 -MemoryStartupBytes 4096MB -SwitchName $VM.SwitchName -Path $VM.Path -NoVHD
        # Create the VHDX files with the specified size and block size, and add it to the VM
            log -Message "Creating virtual disks for VM: $($VM.Name)" -Level "INFO"
            foreach ($disk in $($VM.disks.disk | Sort-object number)) {
                $VHDPath = "$(($newvm).path)\Virtual Hard Disks\$($disk.Name).vhdx"
                New-VHD -Path $VHDPath -SizeBytes ([int]$disk.SizeGB * 1GB) -BlockSizeBytes 1MB -Dynamic | Out-null
                Add-VMHardDiskDrive -VMName $VM.Name -Path $VHDPath
                log -Message "Created and added disk: $($disk.Name).vhdx with size $($disk.SizeGB) GB" -Level "INFO"
            }
        # Configure the VM
            log -Message "Configuring VM: $($VM.Name)" -Level "INFO"
            Set-VM -Name $VM.Name -ProcessorCount 2 -CheckpointType Production -AutomaticCheckpointsEnabled $false -SnapshotFileLocation "$($newvm.Path)\Snapshot"
            log -Message "Set processor count to 2, checkpoint type to Production, and disabled automatic checkpoints for VM: $($VM.Name)" -Level "INFO"

        # Adding CD-ROM drives to the VM
            log -Message "Adding CD-ROM drives to VM: $($VM.Name)" -Level "INFO"
            foreach ($cdrom in $VM.cdroms.cdrom) {
                $SCSIController = Get-VMScsiController -VMName $VM.Name
                log -Message "adding : $($cdrom.name)" -Level "INFO"
                $DVDLocation = (0..63 | Where-Object { $(($SCSIController).drives | Select-Object -ExpandProperty ControllerLocation) -notcontains $_ })[-1]
                Add-VMDvdDrive -VMName $VM.Name -Path $cdrom.ISO -ControllerNumber $SCSIController.ControllerNumber -ControllerLocation $DVDLocation
                log -Message "Added CD-ROM drive: $($cdrom.name) with ISO: $($cdrom.iso)" -Level "INFO"
            }
        # set VLAN for the VM if specified
            if ($vm.vlan) {
                set-VMNetworkAdapterVlan -VMName $VM.Name -Access -VlanId $vm.vlan
                log -Message "Set VLAN ID $($vm.vlan) for VM: $($VM.Name)" -Level "INFO"
            }

        # Select the first DVD drive as the primary boot device
            $DVDDrive = Get-VMDvdDrive -VMName $VM.Name | Sort-Object ControllerLocation -Descending | Select-Object -first 1
            log -Message "Setting firmware boot order for VM: $($VM.Name)" -Level "INFO"

        # set the first DVD drive as the primary boot device
            Set-VMFirmware -BootOrder $DVDDrive -VMName $VM.Name
            log -message "Firmware boot order set to CD-ROM drive: $($DVDDrive.Name) for VM: $($VM.Name)" -Level "INFO"
        # Configures a key protector for a virtual machine.
            log -Message "Configuring secure boot for VM: $($VM.Name)" -Level "INFO"
            Set-VMKeyProtector -VMName $VM.Name -NewLocalKeyProtector
            log -message "Secure boot configured for VM: $($VM.Name)" -Level "INFO"
        # Enables a virtual Trusted Platform Module (TPM) for a virtual machine.
            log -Message "Enabling TPM for VM: $($VM.Name)" -Level "INFO"
            Enable-VMTPM -VMName $VM.Name
            log -Message "TPM enabled for VM: $($VM.Name)" -Level "INFO"
        # start the VM
            log -Message "Starting VM: $($VM.Name)" -Level "INFO"
            Start-VM -Name $VM.Name
            log -Message "VM $($VM.Name) started successfully." -Level "INFO"
        # final log message
            log -Message "VM $($VM.Name) created and started successfully." -Level "INFO"
        }
    }
}
end {
    log -Message "Script execution completed." -Level "INFO"
}