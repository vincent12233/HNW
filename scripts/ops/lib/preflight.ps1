param([Parameter(Mandatory)][string]$Environment)
$ErrorActionPreference = 'Stop'
if ($Environment -notmatch '^[a-z0-9][a-z0-9-]{1,31}$') { throw 'Unknown or invalid environment name' }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker is required' }
docker info *> $null
if ($LASTEXITCODE -ne 0) { throw 'Docker daemon is unavailable' }
$envFile = Join-Path $PSScriptRoot "../../../.env.$Environment"
if (-not (Test-Path -LiteralPath $envFile)) { throw "Environment file not found: .env.$Environment" }
$free = (Get-PSDrive -Name ([IO.Path]::GetPathRoot((Resolve-Path $PSScriptRoot)).TrimEnd(':\'))).Free
if ($free -lt 10GB) { throw 'At least 10 GB free disk space is required' }
@{ environment = $Environment; envFile = (Resolve-Path $envFile).Path; diskFreeBytes = $free }
