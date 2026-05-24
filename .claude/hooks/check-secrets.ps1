#!/usr/bin/env pwsh
# PreToolUse hook: block Write/Edit/MultiEdit if content looks like a secret,
# or if the target filename matches a known credential-bearing pattern.
# This repo is PUBLIC on GitHub — defense in depth alongside .gitignore.
#
# Exit codes: 0 = allow, 2 = block (stderr is shown to Claude).

$ErrorActionPreference = 'Stop'

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }

try {
  $payload = $raw | ConvertFrom-Json
} catch {
  exit 0
}

$toolName  = $payload.tool_name
$toolInput = $payload.tool_input
if (-not $toolInput) { exit 0 }

$filePath = $toolInput.file_path
$texts = New-Object System.Collections.ArrayList

switch ($toolName) {
  'Write'     { [void]$texts.Add([string]$toolInput.content) }
  'Edit'      { [void]$texts.Add([string]$toolInput.new_string) }
  'MultiEdit' {
    foreach ($e in $toolInput.edits) {
      [void]$texts.Add([string]$e.new_string)
    }
  }
  default     { exit 0 }
}

$blockedFileNames = @(
  '\.env(\.|$)',
  '\.pem$',
  '\.key$',
  '\.p12$',
  '\.pfx$',
  '\.jks$',
  '\.keystore$',
  'id_rsa($|\.)',
  'credentials($|\.json$|\.csv$)',
  'service-account.*\.json$',
  'aws/credentials$',
  'gcp.*key.*\.json$',
  'keystore\.properties$',
  'key\.properties$',
  'signing\.properties$'
)

if ($filePath) {
  $normalized = ($filePath -replace '\\', '/').ToLower()
  foreach ($pat in $blockedFileNames) {
    if ($normalized -match $pat) {
      [Console]::Error.WriteLine("BLOCKED by secret-guard: filename '$filePath' matches credential-bearing pattern /$pat/. This repo is PUBLIC. Use a *.example template + .env (gitignored) + runtime injection (AWS Secrets Manager / env var) instead.")
      exit 2
    }
  }
}

$patterns = @(
  @{ name='AWS Access Key ID';            rx='AKIA[0-9A-Z]{16}' },
  @{ name='AWS Secret Access Key assignment'; rx='(?i)aws_secret_access_key\s*[:=]\s*["'']?[A-Za-z0-9/+=]{30,}' },
  @{ name='PRIVATE KEY block';            rx='-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----' },
  @{ name='GitHub Personal Access Token'; rx='ghp_[A-Za-z0-9]{36,}' },
  @{ name='GitHub fine-grained token';    rx='github_pat_[A-Za-z0-9_]{82,}' },
  @{ name='Google API key';               rx='AIza[0-9A-Za-z_\-]{35}' },
  @{ name='Slack token';                  rx='xox[abpsr]-[A-Za-z0-9-]{10,}' },
  @{ name='Stripe live key';              rx='sk_live_[A-Za-z0-9]{20,}' },
  @{ name='Generic JWT';                  rx='eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' }
)

foreach ($t in $texts) {
  if (-not $t) { continue }
  foreach ($p in $patterns) {
    if ($t -match $p.rx) {
      [Console]::Error.WriteLine("BLOCKED by secret-guard: content matches '$($p.name)'. This repo is PUBLIC — never embed credentials. Reference by env-var name (e.g. System.getenv(\""AWS_ACCESS_KEY_ID\"")) and inject at runtime via AWS Secrets Manager / Parameter Store.")
      exit 2
    }
  }
}

exit 0
