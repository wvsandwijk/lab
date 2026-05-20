$scripts = @(
    {
        # Create event log for automation and write an entry to indicate that the event log was created

        New-Item -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\$EventSource\$EventlogName -Force -ErrorAction 'SilentlyContinue';
        New-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\$EventSource\$EventlogName -Name EventLogName -PropertyType String -Value $EventlogName -Force;
        New-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\$EventSource\$EventlogName -Name EventSource -PropertyType String -Value $EventSource -Force;
        New-EventLog -LogName $EventlogName -Source $EventSource -ErrorAction  'SilentlyContinue';
        Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message "Created eventlog for automation`n`rEventlogname: $eventlogName`r`nEventSource: $EventSource";
    };
    {
        # Create system environment variables for event log name and source to be used by other scripts

        New-ItemProperty -Path $SystemEnvironment -Name 'AutomationEventLogName' -PropertyType String -Value $EventlogName -Force;
        New-ItemProperty -Path $SystemEnvironment -Name 'AutomationEventSource' -PropertyType String -Value $EventSource -Force;
        Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message "Created system environment variables for automation event log`n`AutomationEventLogName: $eventlogName`r`AutomationEventSource: $EventSource";
    };
    {
        # Set network location to private to allow file sharing and other features that are disabled on public networks

        $Netprofile = Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
        Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message "Set network location to private`r`nNetwork name: $($Netprofile.Name)`r`nInterface alias: $($Netprofile.InterfaceAlias)`r`nInterface index: $($Netprofile.InterfaceIndex)`r`nNetwork category: $($Netprofile.NetworkCategory)";
    }
    {
        # Rename computer to match the virtual machine name if running inside a virtual machine

        if ((Get-CimInstance cim_computersystem).model -match 'Virtual Machine') {
            $currentComputername = $env:COMPUTERNAME
            $vmname = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters' -Name VirtualMachineName).VirtualMachineName
            if ($currentComputername -ne $vmname) {
                Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message "Renaming computer from $currentComputername to $vmname";
                Rename-Computer -NewName $vmname -restart
            }
            else {
                Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message "Computer name $currentComputername already matches the virtual machine name. No rename needed.";
                Write-Host "Computer name already matches the virtual machine name. No rename needed."
            }
        }
        else {
            Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message "Not running inside a virtual machine. Skipping computer rename.";
            Write-Host "Not running inside a virtual machine. Skipping computer rename."
        }
    };
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

    [float]$complete = 0;
    [float]$increment = 100 / $scripts.Count;
    [string]$EventlogName = 'LAWN Automation';
    [string]$EventSource = 'Automation';
    [string]$SystemEnvironment = 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment';

    foreach ( $script in $scripts ) {
        #Write-Progress -Id 0 -Activity 'Running scripts to finalize your Windows installation. Do not close this window.' -PercentComplete $complete;
        '{0} - {1}' -f $(Get-date -f 'yyyy/MM/dd-HH:mm:ss'), $((($script.ToString().trim() -split '\n')[0] -replace ('#', '')).trim());
        $start = [datetime]::Now;
        & $script;
        '{0} - Executed in {1:0} ms.' -f $(Get-date -f 'yyyy/MM/dd-HH:mm:ss'), $([datetime]::Now.Subtract( $start ).TotalMilliseconds);
        $complete += $increment;
    }
    Stop-Transcript;
    Start-Sleep -Seconds 10;
};