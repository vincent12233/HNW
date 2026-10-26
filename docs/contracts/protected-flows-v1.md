# HNW Protected Flows Contract v1

This contract is the release guard for customer authentication, assisted funding, and equity orders. UI hierarchy and copy may improve; the behavior below may change only through a separately approved product decision.

| Flow | Method and route | Required request fields | Forbidden request fields | Observable result and authoritative effect |
| --- | --- | --- | --- | --- |
| Register | `POST /auth/register` | `phone`, `password`, `inviteCode` | email, SMS OTP, payment details | Creates one suspended CLIENT linked to the invite owner and an INR account; returns a short-lived KYC onboarding token, never a customer session. |
| Login | `POST /auth/login` | `phone`, `password` | email, SMS OTP | Returns the current bearer session for an eligible client. `verificationCode` is permitted only for the existing authenticator/recovery-code challenge. |
| Forgot password | Existing support recovery lifecycle | registered phone, support-issued recovery code, new password at confirmation | self-service SMS/email OTP | Customer contacts support; only an authorized HNW recovery action can issue the one-time code. |
| Deposit | `GET /deposit/my`; customer support entry | authenticated customer for history | customer-created deposit/payment submission | Customer obtains payment details from support; finance records and confirms the manual credit. The App never self-credits funds. |
| Place order | `POST /orders` | `clientOrderId`, `exchange`, `symbol`, `side`, `type`, `timeInForce`, `quantity`; `limitPrice` for LIMIT | new order/product fields | Preserves BUY/SELL, MARKET/LIMIT, DAY/IOC/FOK, current validation, freeze, matching, settlement, and account-scoped idempotency. |
| Cancel order | `POST /orders/:id/cancel` | authenticated order identity | blind retry that creates a new order | Produces one legal terminal/current state; a lost response is recovered by querying existing order state. |

## Client presentation requirements

- Registration visibly contains phone, password, confirm password, and invite code; it contains no SMS OTP, email, or third-party registration requirement.
- Login visibly contains phone and password. The authenticator/recovery-code field appears only after the existing challenge.
- Forgot password explains the support-issued recovery-code process.
- Deposit opens customer support and shows finance-confirmed history; it provides no self-service payment form.
- The order ticket retains side, type, time in force, quantity, limit price rules, confirmation, and the same payload.

Run `scripts/verify-protected-flows.ps1` on Windows or `scripts/verify-protected-flows.sh` on Unix before broader suites.
