param(
    [string]$GodotPath = 'godot',
    [string]$Filter = 'test_*'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = (Get-Command $GodotPath -ErrorAction Stop).Source
$logDirectory = Join-Path $projectRoot ('.codex-temp/qa-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$cases = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests') -Filter "$Filter.tscn")
if ('test_damage_calculator' -like $Filter) {
    $cases += Get-Item -LiteralPath (Join-Path $projectRoot 'tests/test_damage_calculator.gd')
}
if ($cases.Count -eq 0) { throw '没有匹配的测试。' }
$failed = 0
$assertions = 0
foreach ($case in $cases) {
    $stdout = Join-Path $logDirectory ($case.BaseName + '.out.log')
    $stderr = Join-Path $logDirectory ($case.BaseName + '.err.log')
    $mode = if ($case.Extension -eq '.gd') { '--script ' } else { '' }
    $arguments = '--headless --fixed-fps 60 --path "' + $projectRoot + '" --quit-after 6000 ' + $mode + 'res://tests/' + $case.Name
    $process = Start-Process -FilePath $enginePath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $completed = $process.WaitForExit(30000)
    if (-not $completed) { $process.Kill(); $process.WaitForExit() }
    $output = (Get-Content -LiteralPath $stdout -Raw) + (Get-Content -LiteralPath $stderr -Raw)
    $passes = ([regex]::Matches($output, '(?m)^PASS:')).Count
    $assertions += $passes
    if (-not $completed -or $process.ExitCode -ne 0 -or $output -match 'SCRIPT ERROR|ERROR:|FAIL:' -or $passes -eq 0) {
        $failed++
        Write-Output "失败: $($case.Name)；通过断言 $passes"
        Write-Output $output
    } else {
        Write-Output "通过: $($case.Name)；断言 $passes"
    }
}
Write-Output "总计: $($cases.Count) 组；$assertions 项通过断言；$failed 组失败。日志: $logDirectory"
if ($failed -gt 0) { exit 1 }
