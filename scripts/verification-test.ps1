param(
  [string]$BaseUrl = "http://localhost:3000"
)

$ErrorActionPreference = "Stop"

$requiredPasswords = @{
  BUSINESS = $env:BUSINESS_INITIAL_PASSWORD
  SUPPORT = $env:SUPPORT_INITIAL_PASSWORD
  FINANCE = $env:FINANCE_INITIAL_PASSWORD
  ADMIN = $env:ADMIN_INITIAL_PASSWORD
}
foreach ($entry in $requiredPasswords.GetEnumerator()) {
  if ([string]::IsNullOrWhiteSpace($entry.Value)) {
    throw "$($entry.Key)_INITIAL_PASSWORD must be set before running verification."
  }
}

function Invoke-JsonPost($Url, $Body, $Token = $null) {
  $headers = @{}
  if ($Token) {
    $headers.Authorization = "Bearer $Token"
  }

  $json = $Body | ConvertTo-Json -Depth 10
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

  Invoke-RestMethod `
    -Method Post `
    -Uri "$BaseUrl$Url" `
    -ContentType "application/json; charset=utf-8" `
    -Headers $headers `
    -Body $bytes
}

function Invoke-JsonPatch($Url, $Body, $Token = $null) {
  $headers = @{}
  if ($Token) {
    $headers.Authorization = "Bearer $Token"
  }

  $json = $Body | ConvertTo-Json -Depth 10
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

  Invoke-RestMethod `
    -Method Patch `
    -Uri "$BaseUrl$Url" `
    -ContentType "application/json; charset=utf-8" `
    -Headers $headers `
    -Body $bytes
}

function Invoke-JsonGet($Url, $Token = $null) {
  $headers = @{}
  if ($Token) {
    $headers.Authorization = "Bearer $Token"
  }

  Invoke-RestMethod -Method Get -Uri "$BaseUrl$Url" -Headers $headers
}

$stamp = Get-Date -Format "HHmmss"
$phone = "97$stamp" + "00"
$clientPassword = "Client@123456"

$business = Invoke-JsonPost "/auth/login" @{
  employeeNo = "BUSINESS001"
  password = $requiredPasswords.BUSINESS
}
$businessToken = $business.accessToken

$codes = Invoke-JsonGet "/business/invite-codes" $businessToken
$invite = ($codes | Where-Object { $_.status -eq "UNUSED" } | Select-Object -First 1).code
$generatedInvite = $false
if (-not $invite) {
  $generatedCodes = Invoke-JsonPost "/business/self/invite-codes" @{
    count = 3
  } $businessToken

  $invite = ($generatedCodes | Where-Object { $_.status -eq "UNUSED" } | Select-Object -First 1).code
  $generatedInvite = $true
}

if (-not $invite) {
  throw "No unused invite code available, and automatic invite generation failed."
}

$registration = Invoke-JsonPost "/auth/register" @{
  phone = $phone
  password = $clientPassword
  inviteCode = $invite
}
$kycToken = $registration.kycToken
if (-not $kycToken) { throw "Registration did not return a KYC onboarding token." }

$testPdf = "%PDF-1.4`n1 0 obj<</Type/Catalog>>endobj`ntrailer<</Root 1 0 R>>`n%%EOF"
$kycFile = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($testPdf))
# Synthetic PNG fixture used only by the business verification smoke test.
$testImage = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1ZkAAAAASUVORK5CYII='
$kyc = Invoke-JsonPost "/kyc/submit" @{
  phone = $phone
  documentType = "PAN"
  fileName = "pan-card-test.pdf"
  mimeType = "application/pdf"
  contentBase64 = $kycFile
  selfieContentBase64 = $testImage
  selfieMimeType = 'image/png'
  signatureContentBase64 = $testImage
} $kycToken

$pendingKyc = Invoke-JsonGet "/kyc/business/pending" $businessToken
$submission = $pendingKyc | Where-Object { $_.phone -eq $phone } | Select-Object -First 1
if (-not $submission) {
  throw "KYC submission not found for business review."
}

Invoke-JsonPatch "/kyc/business/review" @{
  submissionId = $submission.id
  decision = "APPROVED"
  note = "Verification approved"
} $businessToken | Out-Null

$client = Invoke-JsonPost "/auth/login" @{
  phone = $phone
  password = $clientPassword
}
$clientToken = $client.accessToken
$accountNumber = $client.account.accountNumber

$conversation = Invoke-JsonPost "/support/conversations" @{} $clientToken
Invoke-JsonPost "/support/messages" @{
  conversationId = $conversation.id
  content = "Hello, I would like to make a deposit."
} $clientToken | Out-Null

$support = Invoke-JsonPost "/auth/login" @{
  employeeNo = "SUPPORT001"
  password = $requiredPasswords.SUPPORT
}
$supportToken = $support.accessToken
Invoke-JsonPost "/support/conversations/$($conversation.id)/tags" @{
  tags = @("deposit-support", "priority-client", "pan-submitted")
} $supportToken | Out-Null

$finance = Invoke-JsonPost "/auth/login" @{
  employeeNo = "FINANCE001"
  password = $requiredPasswords.FINANCE
}
$financeToken = $finance.accessToken

$deposit = Invoke-JsonPost "/deposit/support-submit" @{
  conversationId = $conversation.id
  amount = "10000.00"
  referenceId = "VERIFY$stamp"
  paymentMethod = "Verification transfer"
  note = "Automated verification deposit"
} $supportToken
$pendingDeposits = Invoke-JsonGet "/deposit/pending" $financeToken
if (-not ($pendingDeposits | Where-Object { $_.id -eq $deposit.id })) {
  throw "Support-confirmed deposit was not visible to finance."
}
Invoke-JsonPatch "/deposit/$($deposit.id)/approve" @{} $financeToken | Out-Null

$order = Invoke-JsonPost "/orders" @{
  clientOrderId = "VERIFY-ORDER-$stamp"
  exchange = "NSE"
  symbol = "RELIANCE"
  side = "BUY"
  type = "MARKET"
  timeInForce = "DAY"
  quantity = 1
} $clientToken

$admin = Invoke-JsonPost "/auth/login" @{
  employeeNo = "ADMIN001"
  password = $requiredPasswords.ADMIN
}
$adminOrders = Invoke-JsonGet "/admin/orders?pageSize=5&search=VERIFY-ORDER-$stamp" $admin.accessToken
$financeTrades = Invoke-JsonGet "/admin/trades?pageSize=5&search=VERIFY-ORDER-$stamp" $financeToken
$businessOrders = Invoke-JsonGet "/business/my-orders?pageSize=5&search=VERIFY-ORDER-$stamp" $businessToken

$adminCanSeeOrder = [bool](
  $adminOrders.data | Where-Object { $_.clientOrderId -eq "VERIFY-ORDER-$stamp" }
)
$financeCanSeeTrade = [bool](
  $financeTrades.data | Where-Object { $_.order.clientOrderId -eq "VERIFY-ORDER-$stamp" }
)
$businessCanSeeOrder = [bool](
  $businessOrders.data | Where-Object { $_.clientOrderId -eq "VERIFY-ORDER-$stamp" }
)

if (-not $adminCanSeeOrder) {
  throw "Admin backend cannot see order VERIFY-ORDER-$stamp."
}

if (-not $financeCanSeeTrade) {
  throw "Finance backend cannot see trade for order VERIFY-ORDER-$stamp."
}

if (-not $businessCanSeeOrder) {
  throw "Business backend cannot see own customer order VERIFY-ORDER-$stamp."
}

$withdrawal = Invoke-JsonPost "/withdrawal/request" @{
  amount = 1000
  bankName = "HDFC Bank"
  accountNumber = "1234567890"
  ifscCode = "HDFC0001234"
  note = "Verification withdrawal"
} $clientToken

$businessWithdrawals = Invoke-JsonGet "/business/my-withdrawals" $businessToken
$businessCanSeeWithdrawal = [bool](
  $businessWithdrawals | Where-Object { $_.orderNo -eq $withdrawal.orderNo }
)
if (-not $businessCanSeeWithdrawal) {
  throw "Business backend cannot see withdrawal order $($withdrawal.orderNo)."
}

Invoke-JsonPatch "/withdrawal/$($withdrawal.id)/approve" @{} $financeToken | Out-Null

[ordered]@{
  ok = $true
  phone = $phone
  inviteCode = $invite
  generatedInvite = $generatedInvite
  kycRecognizedType = $kyc.recognizedType
  accountNumber = $accountNumber
  orderStatus = $order.order.status
  adminCanSeeOrder = $adminCanSeeOrder
  financeCanSeeTrade = $financeCanSeeTrade
  businessCanSeeOrder = $businessCanSeeOrder
  withdrawalOrderNo = $withdrawal.orderNo
  businessCanSeeWithdrawal = $businessCanSeeWithdrawal
} | ConvertTo-Json -Depth 6
