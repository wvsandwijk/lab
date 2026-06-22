# lab

Procedure

* Download the Windows Server 2025 ISO
* Mount the iso
* Copy the full contents to a folder on your local disk
* create an autounattend file from : [Windows unattended generator](https://schneegans.de/windows/unattend-generator/)
  or
* create an autounattend file from : [Windows unattended file generator](https://windowsunattendedfilegenerator.aeternumtechnology.com/)

```powershell
Get-WindowsImage -ImagePath C:\ISOBUILD\sources\install.wim
```

```text
ImageIndex       : 1
ImageName        : Windows Server 2025 Standard Evaluation
ImageDescription : (Recommended) This option omits most of the Windows graphical environment. Manage with a command prompt and PowerShell, or remotely with Windows Admin Center or other tools.
ImageSize        : 9,009,625,413 bytes

ImageIndex       : 2
ImageName        : Windows Server 2025 Standard Evaluation (Desktop Experience)
ImageDescription : This option installs the full Windows graphical environment, consuming extra drive space. It can be useful if you want to use the Windows desktop or have an app that requires it.
ImageSize        : 18,993,399,495 bytes

ImageIndex       : 3
ImageName        : Windows Server 2025 Datacenter Evaluation
ImageDescription : (Recommended) This option omits most of the Windows graphical environment. Manage with a command prompt and PowerShell, or remotely with Windows Admin Center or other tools.
ImageSize        : 9,009,416,424 bytes

ImageIndex       : 4
ImageName        : Windows Server 2025 Datacenter Evaluation (Desktop Experience)
ImageDescription : This option installs the full Windows graphical environment, consuming extra drive space. It can be useful if you want to use the Windows desktop or have an app that requires it.
ImageSize        : 18,996,367,947 bytes

```

## Create Virtualmachines

```powershell
.\VM.ps1 -Configuration .\Config.xml -Select
```

## Remove VirtualMachines

Remove virtualmachines that you select and match with the config file
The configfile is mandatory. You can not remove files that are not part of the config file

```powershell
.\VM.ps1 -Configuration .\Config.xml -Select -Remove
```
