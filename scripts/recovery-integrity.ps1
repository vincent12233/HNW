function Get-RecoveryFileSha256([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Recovery artifact not found: $Path"
  }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-RecoveryFileChecksum([string]$Path, [string]$ExpectedSha256) {
  if ($ExpectedSha256 -notmatch '^[0-9a-f]{64}$') {
    throw 'Expected recovery checksum must be a lowercase SHA-256 value'
  }
  $actual = Get-RecoveryFileSha256 $Path
  if ($actual -cne $ExpectedSha256) {
    throw "Recovery artifact checksum mismatch: $Path"
  }
  return $actual
}
