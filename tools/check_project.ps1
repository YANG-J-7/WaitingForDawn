$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    'project.godot',
    'src/core/run_state.gd',
    'src/main/main.gd',
    'src/main/main.tscn',
    'docs/project/technical-preferences.md',
    'production/project-state.yaml'
)

foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Missing required file: $relativePath"
    }
}

$projectConfig = Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw
$requiredConfig = @(
    'run/main_scene="res://src/main/main.tscn"',
    'RunState="*res://src/core/run_state.gd"',
    'renderer/rendering_method="gl_compatibility"',
    'window/size/viewport_width=960',
    'window/size/viewport_height=540'
)

foreach ($entry in $requiredConfig) {
    if (-not $projectConfig.Contains($entry)) {
        throw "Missing project setting: $entry"
    }
}

$scene = Get-Content -LiteralPath (Join-Path $projectRoot 'src/main/main.tscn') -Raw
if (-not $scene.Contains('res://src/main/main.gd')) {
    throw 'Main scene does not reference its entry script.'
}

Write-Output 'Waiting for Dawn project structure check passed.'
