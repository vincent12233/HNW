$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '../..')
$script = Join-Path $root 'scripts/verify-github-governance.ps1'
$temp = Join-Path $root '.tmp-governance-test'
$required = @(
  'build-and-test', 'lint-and-build', 'analyze-and-test', 'build-and-contracts',
  'analyze', 'repository-acceptance', 'dependency-review',
  'sbom-and-secrets', 'container-vulnerabilities'
)

function Write-Fixture([string]$Name, [hashtable]$Overrides = @{}) {
  $fixture = @{
    repository = 'vincent12233/HNW'
    defaultBranch = 'main'
    headSha = ('a' * 40)
    branchProtection = @{
      enabled = $true
      enforceAdmins = $true
      requiredApprovingReviewCount = 1
      requiredChecks = $required
      forcePushesBlocked = $true
      deletionsBlocked = $true
    }
    securityAlerts = @{ dependabot = 0; codeScanning = 0; secretScanning = 0 }
    productionEnvironment = @{ exists = $true; reviewers = 1 }
  }
  foreach ($key in $Overrides.Keys) { $fixture[$key] = $Overrides[$key] }
  $path = Join-Path $temp "$Name.json"
  $fixture | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding utf8
  return $path
}

function Invoke-Fixture([string]$Fixture, [string]$Report, [string]$ExpectedSha = ('a' * 40)) {
  $process = Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -Wait -PassThru `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$script`"", '-Repository', 'vincent12233/HNW', '-ExpectedSha', $ExpectedSha, '-FixturePath', "`"$Fixture`"", '-ReportPath', "`"$Report`"")
  return $process.ExitCode
}

try {
  New-Item -ItemType Directory -Force -Path $temp | Out-Null

  $completeReport = Join-Path $temp 'complete-report.json'
  if ((Invoke-Fixture (Write-Fixture 'complete') $completeReport) -ne 0) {
    throw 'Complete governance fixture was rejected'
  }
  $complete = Get-Content -LiteralPath $completeReport -Raw | ConvertFrom-Json
  if (-not $complete.complete -or $complete.sha -ne ('a' * 40)) {
    throw 'Complete governance report is not SHA-bound and complete'
  }

  if ((Invoke-Fixture (Write-Fixture 'stale-sha') (Join-Path $temp 'stale-sha-report.json') ('b' * 40)) -eq 0) {
    throw 'Governance verifier accepted evidence for a different branch HEAD'
  }

  $unprotected = Write-Fixture 'unprotected' @{
    branchProtection = @{ enabled = $false }
  }
  if ((Invoke-Fixture $unprotected (Join-Path $temp 'unprotected-report.json')) -eq 0) {
    throw 'Missing branch protection was accepted'
  }

  $missingChecks = Write-Fixture 'missing-checks' @{
    branchProtection = @{
      enabled = $true; enforceAdmins = $true; requiredApprovingReviewCount = 1
      requiredChecks = @('API CI'); forcePushesBlocked = $true; deletionsBlocked = $true
    }
  }
  if ((Invoke-Fixture $missingChecks (Join-Path $temp 'checks-report.json')) -eq 0) {
    throw 'Missing required checks were accepted'
  }

  $alerts = Write-Fixture 'alerts' @{
    securityAlerts = @{ dependabot = 1; codeScanning = 0; secretScanning = 0 }
  }
  if ((Invoke-Fixture $alerts (Join-Path $temp 'alerts-report.json')) -eq 0) {
    throw 'Open security alerts were accepted'
  }

  $environment = Write-Fixture 'environment' @{
    productionEnvironment = @{ exists = $true; reviewers = 0 }
  }
  if ((Invoke-Fixture $environment (Join-Path $temp 'environment-report.json')) -eq 0) {
    throw 'Production environment without reviewers was accepted'
  }

  Write-Host 'GitHub governance verifier tests passed.' -ForegroundColor Green
} finally {
  if (Test-Path -LiteralPath $temp) {
    Remove-Item -LiteralPath $temp -Recurse -Force
  }
}
