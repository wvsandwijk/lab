$scripts = @(
	{
		# Set AutoLogonCount to 0 to disable auto logon after first logon
		Set-ItemProperty -LiteralPath 'Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoLogonCount' -Type 'DWord' -Force -Value 0;
    Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 2 -Message 'Disabled auto logon';
	};
	{
    # Remove unattend.xml and Wifi.xml to prevent them from being applied on next logon and to clean up the system after OOBE
		Remove-Item -LiteralPath @(
		  'C:\Windows\Panther\unattend.xml';
		  'C:\Windows\Panther\unattend-original.xml';
		  'C:\Windows\Setup\Scripts\Wifi.xml';
		) -Force -ErrorAction 'SilentlyContinue' -Verbose;
    Write-EventLog -LogName $EventlogName -Source $EventSource -EntryType Information -EventId 3 -Message 'Removed unattend.xml and Wifi.xml';
	}
);

&{
  #  https://patorjk.com/software/taag/#p=display&f=Stforek&t=LAWN+Automation+2026%0A&x=none&v=4&h=4&w=80&we=false
  "
    _    __   _   _  __  _    __  _  _ _____ __  __ __  __ _____ _  __  __  _   ___ __ ___ ___  
   | |  /  \ | | | ||  \| |  /  \| || |_   _/__\|  V  |/  \_   _| |/__\|  \| | (_  /  (_  / __| 
   | |_| /\ || 'V' || | ' | | /\ | \/ | | || \/ | \_/ | /\ || | | | \/ | | ' |  / / // / /  _ \ 
   |___|_||_|!_/ \_!|_|\__| |_||_|\__/  |_| \__/|_| |_|_||_||_| |_|\__/|_|\__| |___\__/___\___/ 
  ";
  
  [float]$complete = 0;
  [float]$increment = 100 / $scripts.Count;
  [string]$EventlogName = 'N-WAL';
  [string]$EventSource = 'Automation';

  foreach( $script in $scripts ) {
    Write-Progress -Id 0 -Activity 'Running scripts to finalize your Windows installation. Do not close this window.' -PercentComplete $complete;
    '{0} - {1}' -f $(Get-date -f 'yyyy/MM/dd-HH:mm:ss'),$((($script.ToString().trim() -split '\n')[0] -replace ('#','')).trim());
    $start = [datetime]::Now;
    & $script;
    '{0} - Executed in {1:0} ms.' -f $(Get-date -f 'yyyy/MM/dd-HH:mm:ss'),$([datetime]::Now.Subtract( $start ).TotalMilliseconds);
    $complete += $increment;
  }
} | Out-String -Width 1KB -Stream >> "C:\Windows\Setup\Scripts\$($MyInvocation.MyCommand.Name).log"; start-sleep -Seconds 10