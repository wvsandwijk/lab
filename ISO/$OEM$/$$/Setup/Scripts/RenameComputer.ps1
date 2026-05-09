$scripts = @(
    {
        # create evenlog for automation
            New-Item -Path HKLM:\SOFTWARE\Automation\$EventlogName -Force
            New-ItemProperty -Path HKLM:\SOFTWARE\Automation\$EventlogName -Name EventLogName -PropertyType String -Value $EventlogName
            New-ItemProperty -Path HKLM:\SOFTWARE\Automation\$EventlogName -Name EventSource -PropertyType String -Value $EventSource
            New-EventLog -LogName $EventlogName -Source $EventSource -ErrorAction  'SilentlyContinue';
            Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 1 -Message 'Created event log for automation';

            New-ItemProperty -Path $SystemEnvironment -Name 'AutomationEventLogName' -PropertyType String -Value $EventlogName -Force
            New-ItemProperty -Path $SystemEnvironment -Name 'AutomationEventSource' -PropertyType String -Value $EventSource -Force
            Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 4 -Message 'Created system environment variables for automation event log';
    };
	{
        # RenameComputer.ps1
            if ((Get-CimInstance cim_computersystem).model -match 'Virtual Machine') {
                $currentComputername = $env:COMPUTERNAME
                $vmname=(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters' -Name VirtualMachineName).VirtualMachineName
                if ($currentComputername -ne $vmname) {
                    Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 5 -Message "Renaming computer from $currentComputername to $vmname";
                    Rename-Computer -NewName $vmname -restart
                } else {
                    Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 6 -Message "Computer name $currentComputername already matches the virtual machine name. No rename needed.";
                    Write-Host "Computer name already matches the virtual machine name. No rename needed."
                }
            } else {
                Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 7 -Message "Not running inside a virtual machine. Skipping computer rename.";
                Write-Host "Not running inside a virtual machine. Skipping computer rename."
            }
	};
);

&{
  #  https://patorjk.com/software/taag/#p=display&f=Stforek&t=LAWN+Automation+2026%0A&x=none&v=4&h=4&w=80&we=false
  "    _    __   _   _  __  _    __  _  _ _____ __  __ __  __ _____ _  __  __  _   ___ __ ___ ___  
   | |  /  \ | | | ||  \| |  /  \| || |_   _/__\|  V  |/  \_   _| |/__\|  \| | (_  /  (_  / __| 
   | |_| /\ || 'V' || | ' | | /\ | \/ | | || \/ | \_/ | /\ || | | | \/ | | ' |  / / // / /  _ \ 
   |___|_||_|!_/ \_!|_|\__| |_||_|\__/  |_| \__/|_| |_|_||_||_| |_|\__/|_|\__| |___\__/___\___/ 
  ";

  [float]$complete = 0;
  [float]$increment = 100 / $scripts.Count;
  [string]$EventlogName = 'N-WAL';
  [string]$EventSource = 'Automation';
  [string]$SystemEnvironment = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment';

  foreach( $script in $scripts ) {
    Write-Progress -Id 0 -Activity 'Running scripts to finalize your Windows installation. Do not close this window.' -PercentComplete $complete;
    '{0} - {1}' -f $(Get-date -f 'yyyy/MM/dd-HH:mm:ss'),$((($script.ToString().trim() -split '\n')[0] -replace ('#','')).trim());
    $start = [datetime]::Now;
    & $script;
    '{0} - Executed in {1:0} ms.' -f $(Get-date -f 'yyyy/MM/dd-HH:mm:ss'),$([datetime]::Now.Subtract( $start ).TotalMilliseconds);
    $complete += $increment;
  }
} | Out-String -Width 1KB -Stream >> "C:\Windows\Setup\Scripts\$($MyInvocation.MyCommand.Name).log"; start-sleep -Seconds 10



