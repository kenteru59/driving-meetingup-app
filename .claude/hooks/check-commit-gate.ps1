#!/usr/bin/env pwsh
# PreToolUse hook (Bash matcher): if the command is `git commit ...`, require
# the gradle unit-test suite to pass first. No-op until the Android module
# (app/build.gradle[.kts]) exists, so it doesn't block foundation setup.

$ErrorActionPreference = 'Stop'

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }

try {
  $payload = $raw | ConvertFrom-Json
} catch {
  exit 0
}

$cmd = [string]$payload.tool_input.command
if (-not $cmd) { exit 0 }

if ($cmd -notmatch '(?<![A-Za-z])git\s+commit\b') { exit 0 }
if ($cmd -match '--no-verify') { exit 0 }

if (-not (Test-Path 'app/build.gradle.kts') -and -not (Test-Path 'app/build.gradle')) {
  exit 0
}

$gradlew = $null
if (Test-Path 'gradlew.bat')  { $gradlew = '.\gradlew.bat' }
elseif (Test-Path 'gradlew')  { $gradlew = './gradlew' }
if (-not $gradlew) {
  [Console]::Error.WriteLine("BLOCKED by test-gate: app/build.gradle* exists but no gradlew wrapper found. Run 'gradle wrapper' first or generate the project via Android Studio.")
  exit 2
}

[Console]::Error.WriteLine("Running gradle test gate before commit (testDebugUnitTest)...")
$out = & $gradlew testDebugUnitTest --quiet 2>&1
$rc = $LASTEXITCODE
if ($rc -ne 0) {
  $tail = ($out | Select-Object -Last 40) -join "`n"
  [Console]::Error.WriteLine("BLOCKED by test-gate: gradle testDebugUnitTest failed (exit $rc). Fix the failing tests before committing.`n$tail")
  exit 2
}

exit 0
