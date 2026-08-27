$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    'src/gameplay/combat/damage_calculator.gd',
    'src/gameplay/enemies/enemy_definition.gd',
    'src/gameplay/enemies/enemy.gd',
    'src/gameplay/enemies/enemy.tscn',
    'src/gameplay/waves/wave_definition.gd',
    'src/gameplay/waves/wave_controller.gd',
    'src/data/enemies/wolf.tres',
    'src/data/waves/wave_01.tres',
    'tests/test_damage_calculator.gd',
    'tests/test_first_wave_integration.gd',
    'tests/test_first_wave_integration.tscn'
)

foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Missing Story-001 file: $relativePath"
    }
}

$wolfData = Get-Content -LiteralPath (Join-Path $projectRoot 'src/data/enemies/wolf.tres') -Raw
foreach ($entry in @('threat_points = 5', 'base_damage = 8', 'attack_interval = 0.9', 'rush_multiplier = 1.3', 'rush_duration = 2.0')) {
    if (-not $wolfData.Contains($entry)) {
        throw "Wolf data mismatch: $entry"
    }
}

$waveData = Get-Content -LiteralPath (Join-Path $projectRoot 'src/data/waves/wave_01.tres') -Raw
foreach ($entry in @('enemy_count = 4', 'spawn_interval = 0.6')) {
    if (-not $waveData.Contains($entry)) {
        throw "Wave data mismatch: $entry"
    }
}

Write-Output 'Story-001 static checks passed.'
