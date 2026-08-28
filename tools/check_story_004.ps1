$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    'src/core/run_economy.gd',
    'src/gameplay/buildings/resource_building.gd',
    'src/gameplay/buildings/resource_building.tscn',
    'src/gameplay/buildings/settlement_builder.gd',
    'tests/test_resource_building_placement.gd',
    'tests/test_resource_building_placement.tscn'
)

foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Missing Story-004 file: $relativePath"
    }
}

$project = Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw
if (-not $project.Contains('RunEconomy="*res://src/core/run_economy.gd"')) {
    throw 'RunEconomy autoload is missing.'
}

$mainScene = Get-Content -LiteralPath (Join-Path $projectRoot 'src/main/main.tscn') -Raw
foreach ($entry in @('ResourcesBar', 'SettlementBuilder', 'SettlementSlot0', 'SettlementSlot1', 'SettlementSlot2')) {
    if (-not $mainScene.Contains($entry)) {
        throw "Resource placement scene node missing: $entry"
    }
}

Write-Output 'Story-004 static checks passed.'
