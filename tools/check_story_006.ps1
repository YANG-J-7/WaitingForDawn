$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    'tests/test_manual_worker_assignment.gd',
    'tests/test_manual_worker_assignment.tscn'
)

foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Missing Story-006 file: $relativePath"
    }
}

$mainScene = Get-Content -LiteralPath (Join-Path $projectRoot 'src/main/main.tscn') -Raw
foreach ($entry in @('JobSection', 'JobRows', 'AutoAssignButton', 'JobSummaryLabel')) {
    if (-not $mainScene.Contains($entry)) {
        throw "Worker assignment UI node missing: $entry"
    }
}

Write-Output 'Story-006 static checks passed.'
