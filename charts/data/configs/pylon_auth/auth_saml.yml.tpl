{{- $sso := (default "form" .Values.common.config.sso_provider | lower) -}}

---

{{- if eq $sso "saml"  }}
expiration_override: {{ .Values.common.config.sso_token_expiration }}
authn_destination: {{ .Values.common.config.authn_destination | quote }}
logout_destination: {{ .Values.common.config.logout_destination | quote }}

saml_issuer: {{ .Values.common.config.saml_issuer | quote }}

# multi-line PEMs come from the saml_existing_secret as single-line values with \n escapes
sp_key: "${SAML_SP_KEY}"
sp_cert: "${SAML_SP_CERT}"

{{- if .Values.saml_idp_use_metadata }}
idp_metadata: "${SAML_IDP_METADATA}"
{{- else }}
idp_cert: "${SAML_IDP_CERT}"
{{- end }}
{{- end }}
