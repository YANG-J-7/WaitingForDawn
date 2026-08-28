$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    'src/gameplay/defenses/tower_definition.gd',
    'src/gameplay/defenses/arrow_tower.gd',
    'src/gameplay/defenses/arrow_tower.tscn',
    'src/data/defenses/arrow_tower.tres',
    'tests/test_arrow_tower_wave_clear.gd',
    'tests/test_arrow_tower_wave_clear.tscn'
)

foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Missing Story-002 file: $relativePath"
    }
}

$towerData = Get-Content -LiteralPath (Join-Path $projectRoot 'src/data/defenses/arrow_tower.tres') -Raw
foreach ($entry in @('base_damage = 12', 'attack_interval = 0.8', 'attack_range_tiles = 4.5', '&"wolf": 1.35')) {
    if (-not $towerData.Contains($entry)) {
        throw "Arrow tower data mismatch: $entry"
    }
}

Write-Output 'Story-002 static checks passed.'
