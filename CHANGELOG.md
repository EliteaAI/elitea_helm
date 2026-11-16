## v1.1.0 (2026-11-16)

### Fix

- update chart, elitea version 2.0.8

## v1.0.3 (2026-11-11)

### Feat

- generate empty encryption keys and keep them on upgrade

### Fix

- bump version for fixes

## v1.0.2 (2026-11-11)

### Feat

- create the SecretStore from externalSecret

### Fix

- bump release
- fix readme and code
- keep HMAC/secret keys on upgrade; move hmac_auto_generate under common.secrets
- use 64-byte HMAC keys (hmac_digest is sha512, RFC 7518 requires >= 64 bytes)

## v1.0.1 (2026-11-10)

### Fix

- OIDC SSO rendering; add chart-managed ExternalSecret

## v1.0.0 (2026-11-09)

### Feat

- add tolerations and github_auth secrets, reset chart version to 1.0.0
