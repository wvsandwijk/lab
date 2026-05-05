[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$Path,
    [switch]$Force
)

# Suppress confirmation if -Force is used without explicit -Confirm
if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
    $ConfirmPreference = 'None'
}

if ($PSCmdlet.ShouldProcess($Path, "Remove File")) {
    Remove-Item -Path $Path -Confirm:$false
}