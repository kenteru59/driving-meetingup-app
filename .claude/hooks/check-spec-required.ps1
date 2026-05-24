#!/usr/bin/env pwsh
# PreToolUse hook: block Write/Edit/MultiEdit on app/src/main/** (production code)
# unless at least one spec exists (specs/*/tasks.md). Enforces spec-driven workflow.
# Tests, infra, configs, and non-Android paths are exempt.

$ErrorActionPreference = 'Stop'

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }

try {
  $payload = $raw | ConvertFrom-Json
} catch {
  exit 0
}

$toolInput = $payload.tool_input
if (-not $toolInput -or -not $toolInput.file_path) { exit 0 }

$filePath = ($toolInput.file_path -replace '\\', '/')

$guarded = $false
$context = ''
if ($filePath -match '(^|/)app/src/main/') {
  $guarded = $true; $context = 'Android production code (app/src/main/)'
}
elseif ($filePath -match '(^|/)infra/.*\.(tf|tfvars)$') {
  $guarded = $true; $context = 'Terraform infra (infra/**/*.tf|tfvars)'
}
if (-not $guarded) { exit 0 }

$tasks = Get-ChildItem -Path 'specs' -Filter 'tasks.md' -Recurse -ErrorAction SilentlyContinue
if ($tasks) { exit 0 }

[Console]::Error.WriteLine(@"
BLOCKED by spec-guard: '$filePath' is $context but no specs/*/tasks.md was found.
Spec-driven workflow is mandatory in this project:
  1. /speckit-specify   -> write the feature spec (requirements)
  2. /speckit-plan      -> create the technical plan / design
  3. /speckit-tasks     -> generate the task list
  4. /speckit-implement -> execute (this hook will then allow writes)
Exempt (no spec required): app/src/test/**, app/src/androidTest/**, app/build.gradle*, infra/README.md, infra/docs/**, docs/**, .specify/**, .claude/**, .mcp.json.
"@)
exit 2
