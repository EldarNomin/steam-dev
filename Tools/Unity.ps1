param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Setup', 'Build')]
    [string]$Action,
    [string]$EditorPath = $env:UNITY_EDITOR_PATH
)

$ErrorActionPreference = 'Stop'
if (-not $EditorPath -or -not (Test-Path -LiteralPath $EditorPath -PathType Leaf)) {
    throw 'Provide -EditorPath to Unity.exe or set UNITY_EDITOR_PATH.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$reportsRoot = Join-Path $projectRoot 'Reports'
New-Item -ItemType Directory -Force -Path $reportsRoot | Out-Null
$method = if ($Action -eq 'Setup') {
    'CosmicCatch.Editor.BaselineSetup.SetupBatch'
} else {
    'CosmicCatch.Editor.BuildCommands.BuildWindowsBatch'
}
$logPath = Join-Path $reportsRoot ("unity-{0}.log" -f $Action.ToLowerInvariant())
if ($Action -eq 'Build') {
    # A report from an earlier successful invocation must not satisfy this run.
    $previousReport = Join-Path $reportsRoot 'windows-build.json'
    if (Test-Path $previousReport) { Remove-Item -LiteralPath $previousReport }
}
$editorArguments = @('-batchmode', '-quit', '-projectPath', $projectRoot,
    '-buildTarget', 'Win64', '-executeMethod', $method, '-logFile', $logPath)
# Explicit quoting survives Windows PowerShell 5.1 native argument conversion.
$quotedArguments = $editorArguments | ForEach-Object { '"' + $_ + '"' }
$process = Start-Process -FilePath $EditorPath -ArgumentList $quotedArguments -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "Unity exited with code $($process.ExitCode). See $logPath"
}
if ($Action -eq 'Setup' -and -not (Test-Path (Join-Path $projectRoot 'Assets/_Game/Scenes/Boot.unity'))) {
    throw "Setup did not create Boot.unity. See $logPath"
}
if ($Action -eq 'Build') {
    $evidencePath = Join-Path $reportsRoot 'windows-build.json'
    if (-not (Test-Path $evidencePath)) { throw "No build report. See $logPath" }
    $evidence = Get-Content -Raw $evidencePath | ConvertFrom-Json
    if ($evidence.result -ne 'Succeeded' -or
        -not (Test-Path (Join-Path $projectRoot 'Builds/Windows/CosmicCatch.exe'))) {
        throw "Build artifact or successful report missing. See $logPath"
    }
}
Write-Host "$Action completed. Unity log: $logPath"
