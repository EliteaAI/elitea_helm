{{- $sso := (.Values.common.config.sso_provider | default "form" | lower) -}}

---
{{- if eq $sso "form" }}
metadata_endpoint: ""

client_id: ""
client_secret: ""

url_mode: "external"

{{- else if eq $sso "oidc"  }}
authorization_endpoint: "${AUTHORIZATION_ENDPOINT}"
client_id: ${CLIENT_ID}
client_secret: ${CLIENT_SECRET}
end_session_endpoint: ${END_SESSION_ENDPOINT}
metadata_endpoint: ${METADATA_ENDPOINT}
token_endpoint: ${TOKEN_ENDPOINT}
url_mode: ${URL_MODE}
userinfo_endpoint: ${USERINFO_ENDPOINT}
expiration_override: ${SSO_TOKEN_EXPIRATION}
{{- end }}
