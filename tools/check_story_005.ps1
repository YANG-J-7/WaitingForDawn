$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    'src/gameplay/economy/wave_economy.gd',
    'tests/test_wave_economy_settlement.gd',
    'tests/test_wave_economy_settlement.tscn'
)

foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Missing Story-005 file: $relativePath"
    }
}

$mainScene = Get-Content -LiteralPath (Join-Path $projectRoot 'src/main/main.tscn') -Raw
if (-not $mainScene.Contains('WaveEconomy')) {
    throw 'WaveEconomy scene node is missing.'
}

Write-Output 'Story-005 static checks passed.'
