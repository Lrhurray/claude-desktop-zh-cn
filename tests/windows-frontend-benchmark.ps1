param(
    [Parameter(Mandatory=$true)][string]$InstallerPath,
    [Parameter(Mandatory=$true)][string]$ResourcesPath,
    [Parameter(Mandatory=$true)][string]$RulesPath,
    [ValidateSet('hardcoded','register','labels')][string]$Operation,
    [Parameter(Mandatory=$true)][string]$ResultPath
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new()
. (Join-Path $PSScriptRoot 'frontend-test-support.ps1') $InstallerPath
# AST extraction omits installer setup and never stops Claude or changes AppX.
# Explicit rule-file binding avoids depending on the extracted function's script root.
$script:BenchmarkRules = @((Get-Content -LiteralPath $RulesPath -Raw -Encoding UTF8 | ConvertFrom-Json) |
    Sort-Object -Property @{ Expression = { $_[0].Length }; Descending = $true })
function Get-FrontendHardcodedReplacements { param($Language); return $script:BenchmarkRules }
$watch = [Diagnostics.Stopwatch]::StartNew()
switch ($Operation) {
    hardcoded { Patch-HardcodedFrontendStrings $ResourcesPath 'zh-CN' }
    register { Register-Language $ResourcesPath 'zh-CN' }
    labels { Patch-LanguageDisplayNames $ResourcesPath }
}
$watch.Stop()
[ordered]@{
    powershell = $PSVersionTable.PSVersion.ToString()
    operation = $Operation
    seconds = $watch.Elapsed.TotalSeconds
    nativePatcherLoaded = [bool]('ClaudeZhPatch.FrontendPatcher' -as [type])
    rules = $script:BenchmarkRules.Count
} | ConvertTo-Json | Set-Content -LiteralPath $ResultPath -Encoding UTF8
