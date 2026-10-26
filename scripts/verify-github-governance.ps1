[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[^/]+/[^/]+$')][string]$Repository,
  [string]$Branch = 'main',
  [string]$FixturePath,
  [string]$ReportPath = 'github-governance-report.json'
)

$ErrorActionPreference = 'Stop'
$requiredChecks = @(
  'API CI', 'Admin CI', 'Flutter CI', 'Flutter Integration Tests',
  'Web PWA CI', 'Docker CI', 'CodeQL', 'Production Readiness',
  'Mobile Release Checks', 'Tooling CI'
)

function Invoke-GhJson([string]$Path) {
  $raw = & gh api $Path 2>$null
  if ($LASTEXITCODE -ne 0) { throw "GitHub API request failed: $Path" }
  return $raw | ConvertFrom-Json
}

function Get-LiveState {
  $repo = Invoke-GhJson "/repos/$Repository"
  $branchInfo = Invoke-GhJson "/repos/$Repository/branches/$Branch"
  $protection = $null
  try { $protection = Invoke-GhJson "/repos/$Repository/branches/$Branch/protection" } catch { }

  $environment = $null
  try { $environment = Invoke-GhJson "/repos/$Repository/environments/production" } catch { }

  $dependabot = @(Invoke-GhJson "/repos/$Repository/dependabot/alerts?state=open&per_page=100").Count
  $codeScanning = @(Invoke-GhJson "/repos/$Repository/code-scanning/alerts?state=open&per_page=100").Count
  $secretScanning = @(Invoke-GhJson "/repos/$Repository/secret-scanning/alerts?state=open&per_page=100").Count
  $contexts = @($protection.required_status_checks.contexts)
  if ($protection.required_status_checks.checks) {
    $contexts += @($protection.required_status_checks.checks | ForEach-Object { $_.context })
  }
  $reviewCount = 0
  if ($null -ne $protection.required_pull_request_reviews.required_approving_review_count) {
    $reviewCount = [int]$protection.required_pull_request_reviews.required_approving_review_count
  }

  return @{
    repository = $Repository
    defaultBranch = $repo.default_branch
    headSha = $branchInfo.commit.sha
    branchProtection = @{
      enabled = $null -ne $protection
      enforceAdmins = [bool]$protection.enforce_admins.enabled
      requiredApprovingReviewCount = $reviewCount
      requiredChecks = @($contexts | Sort-Object -Unique)
      forcePushesBlocked = -not [bool]$protection.allow_force_pushes.enabled
      deletionsBlocked = -not [bool]$protection.allow_deletions.enabled
    }
    securityAlerts = @{
      dependabot = $dependabot
      codeScanning = $codeScanning
      secretScanning = $secretScanning
    }
    productionEnvironment = @{
      exists = $null -ne $environment
      reviewers = @($environment.protection_rules | Where-Object { $_.type -eq 'required_reviewers' } | ForEach-Object { $_.reviewers }).Count
    }
  }
}

$state = if ($FixturePath) {
  Get-Content -LiteralPath $FixturePath -Raw | ConvertFrom-Json
} else {
  Get-LiveState
}

$errors = [System.Collections.Generic.List[string]]::new()
if ($state.repository -ne $Repository) { $errors.Add('Repository identity does not match the requested repository') }
if ($state.defaultBranch -ne $Branch) { $errors.Add("Default branch must be $Branch") }
if ($state.headSha -notmatch '^[0-9a-f]{40}$') { $errors.Add('Branch HEAD is not a full commit SHA') }
if (-not $state.branchProtection.enabled) { $errors.Add('Branch protection is not enabled') }
if (-not $state.branchProtection.enforceAdmins) { $errors.Add('Branch protection does not enforce rules for administrators') }
if ([int]$state.branchProtection.requiredApprovingReviewCount -lt 1) { $errors.Add('At least one approving review is required') }
if (-not $state.branchProtection.forcePushesBlocked) { $errors.Add('Force pushes are not blocked') }
if (-not $state.branchProtection.deletionsBlocked) { $errors.Add('Branch deletion is not blocked') }

$configuredChecks = @($state.branchProtection.requiredChecks)
foreach ($check in $requiredChecks) {
  if ($check -notin $configuredChecks) { $errors.Add("Required check is missing: $check") }
}
foreach ($kind in @('dependabot', 'codeScanning', 'secretScanning')) {
  $alertCount = [int]$state.securityAlerts.$kind
  if ($alertCount -gt 0) { $errors.Add("Open ${kind} alerts: $alertCount") }
}
if (-not $state.productionEnvironment.exists) { $errors.Add('Production environment is not configured') }
if ([int]$state.productionEnvironment.reviewers -lt 1) { $errors.Add('Production environment has no required reviewer') }

$report = [ordered]@{
  schemaVersion = 1
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  repository = $Repository
  branch = $Branch
  sha = $state.headSha
  branchProtection = $state.branchProtection
  requiredChecks = $requiredChecks
  securityAlerts = $state.securityAlerts
  productionEnvironment = $state.productionEnvironment
  errors = @($errors)
  complete = $errors.Count -eq 0
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding utf8

if ($errors.Count -gt 0) {
  Write-Error ("GitHub governance verification failed:`n- " + ($errors -join "`n- ")) -ErrorAction Continue
  exit 1
}
Write-Host "GitHub governance verification passed for $Repository@$($state.headSha)." -ForegroundColor Green
