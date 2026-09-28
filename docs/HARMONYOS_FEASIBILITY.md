# HarmonyOS / OpenHarmony Feasibility Gate

Last updated: 2026-09-28
Status: research gate; HarmonyOS is not currently a supported release target.

Flutter source sharing alone does not establish HarmonyOS compatibility. Before
committing to a release, validate each native capability on a physical target
and record the supported plugin/fork, maintainer, license, release cadence, and
fallback.

| Capability | Current dependency | Gate |
|---|---|---|
| Secure credential storage | `flutter_secure_storage` | platform implementation and migration proof |
| Biometric unlock | `local_auth` | supported hardware, lockout, fallback |
| Google sign-in | `google_sign_in` | replace or define market limitation |
| Camera/KYC capture | `camera`, `image_picker` | physical-device capture and permission proof |
| File selection | `file_picker` | document-provider interoperability |
| Package metadata | `package_info_plus` | store build/version proof |
| Browser/deep links | `url_launcher` | allow-list and return-flow proof |
| Realtime market data | `socket_io_client` | suspension/reconnect/load proof |
| Charts | `k_chart` | rendering/performance proof |

Proceed only after product confirms the target market and all P0 capabilities
have maintained implementations. Keep Harmony-specific platform code behind
interfaces; do not fork business rules or financial calculations.
