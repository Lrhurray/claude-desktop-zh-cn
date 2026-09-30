param(
    [Parameter(Mandatory=$true)][string]$InstallerPath,
    [Parameter(Mandatory=$true)][string]$AssetsDir,
    [Parameter(Mandatory=$true)][string]$ResultPath,
    [Parameter(Mandatory=$true)][string]$RulesPath
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new()
. (Join-Path $PSScriptRoot 'frontend-test-support.ps1') $InstallerPath
$jsFiles = @(Get-ChildItem (Join-Path $AssetsDir '*.js') -File)
$rulePairs = @((Get-Content -LiteralPath $RulesPath -Raw -Encoding UTF8 | ConvertFrom-Json) |
    Sort-Object -Property @{ Expression = { $_[0].Length }; Descending = $true })
# Same rule preparation as Patch-HardcodedFrontendStrings.
$prepared = New-Object 'System.Collections.Generic.List[object[]]'
foreach ($pair in $rulePairs) {
    $source = [string]$pair[0]
    $target = [string]$pair[1]
    if (Test-StructuralJsReplacement $source) { continue }
    if (Test-PlainUiTextReplacement $source) {
        $pattern = '(?<quote>[\"''`])' + [System.Text.RegularExpressions.Regex]::Escape($source) + '\k<quote>'
        $prepared.Add([object[]]@([System.Text.RegularExpressions.Regex]::new($pattern), $source, $target))
    } else {
        $prepared.Add([object[]]@($null, $source, $target))
    }
}
$watch = [Diagnostics.Stopwatch]::StartNew()
$patchedFiles = 0
$patchedStrings = 0
foreach ($file in $jsFiles) {
    $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $patched = $text
    $count = 0
    foreach ($rule in $prepared) {
        $result = Replace-FrontendHardcodedText $patched [string]$rule[1] [string]$rule[2]
        if ($result['Count'] -gt 0) {
            $patched = $result['Text']
            $count += $result['Count']
        }
    }
    if ($patched -ne $text) { $patchedFiles++; $patchedStrings += $count }
}
$watch.Stop()
[ordered]@{
    powershell = $PSVersionTable.PSVersion.ToString()
    mode = 'pure-powershell-fallback'
    files = $jsFiles.Count
    rules = $prepared.Count
    seconds = $watch.Elapsed.TotalSeconds
    patchedFiles = $patchedFiles
    patchedStrings = $patchedStrings
} | ConvertTo-Json | Set-Content -LiteralPath $ResultPath -Encoding UTF8
