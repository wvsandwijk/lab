[cmdletbinding()]
param (
    $SourceIsoPath = "C:\ISO\w2025.iso",
    $ISOBuildPath = "C:\ISOBuild",
    $DestinationIsoPath = "C:\ISO\w2025_custom.iso",
    $UnattendXmlPath = "$PSScriptRoot\autounattend.xml",
    $customFilesPath = "$PSScriptRoot\ISO\CustomFiles",
    [switch]$createISO,
    [switch]$force
)

if (-not $createISO) {
    Write-Host "ISO creation skipped. Use -createISO switch to generate the ISO." -ForegroundColor Yellow
    # Ensure the build directory exists
    if (-Not (Test-Path -Path $ISOBuildPath)) {
        New-Item -ItemType Directory -Path $ISOBuildPath | Out-Null
    } else {
        Write-Host "Cleaning existing build directory..." -ForegroundColor Yellow
        Get-ChildItem -Path $ISOBuildPath -Recurse | Remove-Item -Force -Confirm:$false
    }

    # Mount the source ISO
    try { 
        Get-item -Path $SourceIsoPath -ErrorAction Stop | Out-Null
        $mountResult = Mount-DiskImage -ImagePath $SourceIsoPath -PassThru
    } catch {
            Write-Error "Failed to mount ISO image at $SourceIsoPath"
            exit 1
    }

    $driveLetter = ($mountResult | Get-Volume).DriveLetter
    if ($null -eq $driveLetter) {
        Write-Error "Failed to retrieve drive letter for mounted ISO."
        exit 1
    }   
    $sourcePath = "$($driveLetter):\"
    Write-Host "Mounted ISO at drive $driveLetter" -ForegroundColor Green

    # Copy contents from the mounted ISO to the build directory
    Write-Host "Copying files from $sourcePath to $ISOBuildPath..." -ForegroundColor Green
    Copy-Item -Path "$sourcePath*" -Destination $ISOBuildPath -Recurse -Force

    # Unmount the source ISO
    Dismount-DiskImage -ImagePath $SourceIsoPath
    Write-Host "Unmounted source ISO." -ForegroundColor Green

    # Copy unattend.xml to the build directory
    if (Test-Path -Path $UnattendXmlPath) {
        Write-Host "Copying unattend.xml to build directory..." -ForegroundColor Green
        Copy-Item -Path $UnattendXmlPath -Destination "$ISOBuildPath\unattend.xml" -Force
    } else {
        Write-Warning "Unattend XML file not found at $UnattendXmlPath. Skipping copy."
    }

    # Copy custom files to the build directory
    if (Test-Path -Path $customFilesPath) {
        Write-Host "Copying custom files to build directory..." -ForegroundColor Green
        Copy-Item -Path "$customFilesPath\*" -Destination "$ISOBuildPath" -Recurse -Force
    } else {
        Write-Warning "Custom files path not found at $customFilesPath. Skipping copy."
    }
}
if ($createISO) {
    Write-Host "Creating ISO file at $DestinationIsoPath..." -ForegroundColor Green
    Import-Module -Name MyModule
        New-ISOFile -Source $ISOBuildPath -destinationIso $DestinationIsoPath -bootFile "$ISOBuildPath\efi\microsoft\boot\efisys_noprompt.bin" -title "Custom Windows 2025 ISO" -force
    Write-Host "ISO creation complete. Output at $DestinationIsoPath" -ForegroundColor Green
}
