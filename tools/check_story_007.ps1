$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    'design/gdd/card-drag-placement-system.md',
    'production/stories/story-007-card-drag-placement.md',
    'src/gameplay/cards/hand_card_slot.gd',
    'src/gameplay/cards/card_drop_slot.gd',
    'tests/test_card_drag_placement.gd',
    'tests/test_card_drag_placement.tscn'
)

foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Missing Story-007 file: $relativePath"
    }
}

$mainScene = Get-Content -LiteralPath (Join-Path $projectRoot 'src/main/main.tscn') -Raw
foreach ($entry in @('HandBar', 'HandSlots', 'card_drop_slot.gd', 'accepted_category = "resource"', 'accepted_card_ids')) {
    if (-not $mainScene.Contains($entry)) {
        throw "Card drag scene wiring missing: $entry"
    }
}

Write-Output 'Story-007 static checks passed.'
