$p = Join-Path $PSScriptRoot 'dev.ps1'
$tokens = $null
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$tokens, [ref]$errors)
if ($errors.Count) {
    $errors | ForEach-Object { Write-Output $_.Message }
    exit 1
}
Write-Output 'Syntax OK'
