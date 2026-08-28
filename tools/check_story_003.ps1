$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    'src/gameplay/cards/card_definition.gd',
    'src/gameplay/cards/opening_draft.gd',
    'src/data/cards/lumber_camp.tres',
    'src/data/cards/farm.tres',
    'src/data/cards/gold_mine.tres',
    'src/data/cards/arrow_tower_card.tres',
    'src/data/cards/wall.tres',
    'src/data/cards/barracks.tres',
    'tests/test_opening_day_draft.gd',
    'tests/test_opening_day_draft.tscn'
)

foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Missing Story-003 file: $relativePath"
    }
}

$mainScene = Get-Content -LiteralPath (Join-Path $projectRoot 'src/main/main.tscn') -Raw
foreach ($entry in @('DaySetupPanel', 'CardGrid', 'DefenseSlotButton', 'OpeningDraft')) {
    if (-not $mainScene.Contains($entry)) {
        throw "Opening day scene node missing: $entry"
    }
}

Write-Output 'Story-003 static checks passed.'
