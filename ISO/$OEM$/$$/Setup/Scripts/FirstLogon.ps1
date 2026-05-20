$scripts = @(
    {
        # Set AutoLogonCount to 0 to disable auto logon after first logon

        Set-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoLogonCount' -Type 'DWord' -Force -Value 0
        Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message 'Disabled auto logon'
    };
    {
        # Remove unattend.xml and Wifi.xml to prevent them from being applied on next logon and to clean up the system after OOBE

        Remove-Item -LiteralPath @(
            'C:\Windows\Panther\unattend.xml'
            'C:\Windows\Panther\unattend-original.xml'
            'C:\Windows\Setup\Scripts\Wifi.xml'
        ) -Force -ErrorAction 'SilentlyContinue' -Verbose
        Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message 'Removed unattend.xml and Wifi.xml'
    };
    {
        # Set sshd service to start automatically and start the service if it is not already running

        $SSHd_Service = Get-Service -Name sshd
        if ($SSHd_Service.startmode -ne 'Automatic' ) {
            Set-Service -Name sshd -StartupType Automatic
            if ($SSHd_Service.Started -eq $false) {
                Start-Service -Name sshd -ErrorAction 'SilentlyContinue'
            }
            Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message 'Set sshd service to start automatically'
        }
        else {
            Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message 'sshd service is already set to start automatically'
        }
    };
    {
        # Add SSH public key to administrators_authorized_keys

        # $file = Invoke-WebRequest -UseBasicParsing -Uri http://netdisk:8081/repository/raw-hosted/certs/ssh/id_ed25519_AnsibleAdmin.pub

        # [byte[]]$bytes = $file.Content
        # if ($bytes | Where-Object { $_ -lt 0 -or $_ -gt 127 }) {
        #     throw "One or more values are outside the ASCII range (0127)."
        # }
        # $sshKey = [System.Text.Encoding]::ASCII.GetString($bytes)
        $sshkey = Get-Content 'C:\ProgramData\LAWN Automation\id_ed25519_AnsibleAdmin.pub'
        $sshDir = "$env:ProgramData\ssh"
        if (-not (Test-Path -Path $sshDir)) {
            New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        }
        $authorizedKeysPath = Join-Path -Path $sshDir -ChildPath 'administrators_authorized_keys'
        Add-Content -Path $authorizedKeysPath -Value $sshKey
        Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message 'Added SSH public key to administrators_authorized_keys'
    };
    {
        # Set Default lockscreen background and prevent users from changing it

        New-item -path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\SystemProtectedUserData\S-1-5-18\AnyoneRead\LockScreen' -Force
        Set-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\SystemProtectedUserData\S-1-5-18\AnyoneRead\LockScreen' -Name 'GPImagePath_P' -Type 'string' -Value $LockScreenImage -Force

        New-item -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Force
        Set-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name 'LockScreenImage' -Type 'string' -Value $LockScreenImage -Force
        Set-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name 'LockScreenOverlaysDisabled' -Type 'DWord' -Value 1 -Force
        Set-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name 'NoChangingLockScreen' -Type 'DWord' -Value 1 -Force

        New-item -path 'Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Force
        Set-ItemProperty -LiteralPath 'Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'Wallpaper' -Value $LockScreenImage -Force
        Set-ItemProperty -LiteralPath 'Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'WallpaperStyle' -Type 'DWord' -Value 2 -Force

        New-item -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Desktop' -Force
        Set-ItemProperty -LiteralPath 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Desktop' -Name 'Wallpaper' -Value $LockScreenImage -Force

        Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message 'Set default lockscreen background and prevented users from changing it'
    };
    {
        # Run gpupdate /force to apply group policies immediately

        gpupdate /force
        Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message 'Ran gpupdate /force to apply group policies'
    };
    {
        # Eject all CD-ROM drives to prevent the system from trying to boot from the installation media on next logon

        Get-CimInstance -Class Win32_CDROMDrive | ForEach-Object { $_.Eject() }
        Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message 'Ejected all CD-ROM drives'
    };
    {
        # Restart Computer

        Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message 'Restart Computer'
        Restart-Computer
    }
);

& {
    Start-Transcript -Path "C:\Windows\Setup\Scripts\$(Split-Path -Path $PSCommandPath -Leaf).log" -IncludeInvocationHeader -NoClobber -Force;

    #  https://patorjk.com/software/taag/#p=display&f=Stforek&t=LAWN+Automation+2026%0A&x=none&v=4&h=4&w=80&we=false
    "
    _    __   _   _  __  _    __  _  _ _____ __  __ __  __ _____ _  __  __  _   ___ __ ___ ___
   | |  /  \ | | | ||  \| |  /  \| || |_   _/__\|  V  |/  \_   _| |/__\|  \| | (_  /  (_  / __|
   | |_| /\ || 'V' || | ' | | /\ | \/ | | || \/ | \_/ | /\ || | | | \/ | | ' |  / / // / /  _ \
   |___|_||_|!_/ \_!|_|\__| |_||_|\__/  |_| \__/|_| |_|_||_||_| |_|\__/|_|\__| |___\__/___\___/
   ";

    [float]$Complete = 0;
    [float]$Increment = 100 / $Scripts.Count;
    [String]$EventlogName = $env:AutomationEventLogName;
    [String]$EventSource = $env:AutomationEventSource;
    [string]$LockScreenImage = 'C:\ProgramData\LAWN Automation\LAWNAutomationLogonLock.png';

    foreach ( $Script in $Scripts ) {
        #Write-Progress -Id 0 -Activity 'Running scripts to finalize your Windows installation. Do not close this window.' -PercentComplete $Complete;
        '{0} - {1}' -f $(Get-date -f 'yyyy/MM/dd-HH:mm:ss'), $((($Script.ToString().trim() -split '\n')[0] -replace ('#', '')).trim());
        $Start = [datetime]::Now;
        & $Script;
        '{0} - Executed in {1:0} ms.' -f $(Get-date -f 'yyyy/MM/dd-HH:mm:ss'), $([datetime]::Now.Subtract( $Start ).TotalMilliseconds);
        $Complete += $Increment;
    }
    Stop-Transcript;
    Start-Sleep -Seconds 10

};