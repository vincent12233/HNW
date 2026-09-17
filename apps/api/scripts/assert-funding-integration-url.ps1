function Assert-FundingIntegrationDatabaseUrl {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Url
  )

  $trimmed = $Url.Trim()
  if (-not $trimmed) {
    throw 'FUNDING_INTEGRATION_DATABASE_URL is required'
  }

  $uri = $null
  try {
    $uri = [Uri]$trimmed
  } catch {
    throw 'FUNDING_INTEGRATION_DATABASE_URL is not a valid URL'
  }

  $scheme = $uri.Scheme.ToLowerInvariant()
  if ($scheme -ne 'postgres' -and $scheme -ne 'postgresql') {
    throw 'FUNDING_INTEGRATION_DATABASE_URL must use the postgres protocol'
  }

  $hostName = ([string]$uri.Host).Trim().ToLowerInvariant()
  $allowedHosts = @('localhost', '127.0.0.1', 'postgres')
  if ($allowedHosts -notcontains $hostName) {
    throw "Refusing host $($uri.Host). Allowed: localhost, 127.0.0.1, postgres"
  }

  $database = [Uri]::UnescapeDataString($uri.AbsolutePath).Trim('/').Split('/')[0]
  if ($database -notmatch 'test|e2e|integration') {
    throw "Refusing database `"$database`". Name must contain test, e2e, or integration"
  }

  Write-Host "Using isolated database $database on $hostName"
}
