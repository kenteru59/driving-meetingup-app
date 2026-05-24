# Smoke-test any MCP stdio server: send initialize + tools/list via a temp
# stdin file (cmd /c < file), parse JSON-RPC responses, report tool count.
# Not a hook — diagnostic utility. Re-run any time .mcp.json changes.
#
# Usage:
#   .\.claude\hooks\_mcp_smoke.ps1 -Bin uvx   -ArgLine 'mcp-proxy-for-aws@latest --skip-auth https://knowledge-mcp.global.api.aws' -Label aws-knowledge
#   .\.claude\hooks\_mcp_smoke.ps1 -Bin docker -ArgLine 'run -i --rm hashicorp/terraform-mcp-server:0.5.2' -Label terraform

param(
  [Parameter(Mandatory=$true)] [string]$Bin,
  [Parameter(Mandatory=$true)] [string]$ArgLine,
  [Parameter(Mandatory=$true)] [string]$Label
)

$env:PYTHONIOENCODING = 'utf-8'

$batch = @(
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}',
  '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}',
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
) -join "`n"

$tmp = New-TemporaryFile
Set-Content -Path $tmp.FullName -Value $batch -Encoding ascii

Write-Host "==== [$Label] $Bin $ArgLine ====" -ForegroundColor Cyan
$out = & cmd /c "$Bin $ArgLine < `"$($tmp.FullName)`" 2>&1"
Remove-Item $tmp.FullName -ErrorAction SilentlyContinue

$initOk = $false; $toolsOk = $false
foreach ($line in ($out | Where-Object { $_ -match '^\{' })) {
  try { $o = $line | ConvertFrom-Json } catch { continue }
  if ($o.id -eq 1 -and $o.result) {
    $initOk = $true
    Write-Host ("  initialize OK -> {0} v{1} proto={2}" -f `
      $o.result.serverInfo.name, $o.result.serverInfo.version, $o.result.protocolVersion) -ForegroundColor Green
  } elseif ($o.id -eq 2 -and $o.result) {
    $toolsOk = $true
    $names = ($o.result.tools | Select-Object -First 8 -ExpandProperty name) -join ', '
    Write-Host ("  tools/list OK -> {0} tools. First: {1}" -f $o.result.tools.Count, $names) -ForegroundColor Green
  } elseif ($o.error) {
    Write-Host ("  ERROR id={0}: {1}" -f $o.id, $o.error.message) -ForegroundColor Yellow
  }
}

if (-not $initOk)  { Write-Host "  initialize: no response (server may need longer / different transport)" -ForegroundColor Red }
if (-not $toolsOk) { Write-Host "  tools/list: no response (often due to slow upstream + stdin EOF closing process)" -ForegroundColor DarkYellow }

if ($initOk) { exit 0 } else { exit 1 }
