{{- define "elitea.postgresPassword" -}}
{{- $password := .Values.common.secrets.postgres_password | default "" -}}
{{- if not $password -}}
	{{- $secretName := printf "%s-secret" .Values.postgresql.name_prefix -}}
	{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
	{{- if and $existing (hasKey $existing.data "postgres_password") -}}
		{{- $password = index $existing.data "postgres_password" | b64dec -}}
	{{- else -}}
		{{- $password = randAlphaNum 32 -}}
	{{- end -}}
	{{- $_ := set .Values.common.secrets "postgres_password" $password -}}
{{- end -}}
{{- $password -}}
{{- end -}}

{{- define "elitea.redisPassword" -}}
{{- $password := .Values.common.secrets.redis_password | default "" -}}
{{- if not $password -}}
	{{- $secretName := printf "%s-secret" .Values.redis.name_prefix -}}
	{{- $existing := lookup "v1" "Secret" .Release.Namespace $secretName -}}
	{{- if and $existing (hasKey $existing.data "redis_password") -}}
		{{- $password = index $existing.data "redis_password" | b64dec -}}
	{{- else -}}
		{{- $password = randAlphaNum 32 -}}
	{{- end -}}
	{{- $_ := set .Values.common.secrets "redis_password" $password -}}
{{- end -}}
{{- $password -}}
{{- end -}}

{{/* Flattens common.secrets: scalars as-is, one nesting level (hmacs/auth/main) inlined. */}}
{{- define "elitea.commonSecrets" -}}
{{- include "elitea.hmacs" . | trim -}}
{{- if and (not .Values.embedded_services_pgsql) (not .Values.common.secrets.postgres_password) }}{{ fail "common.secrets.postgres_password is required when embedded_services_pgsql is false" }}{{ end -}}
{{- range $k, $v := .Values.common.secrets }}
{{- if eq $k "hmac_auto_generate" }}
{{- else if kindIs "map" $v }}
{{- range $k2, $v2 := $v }}
{{ $k2 }}: {{ $v2 | quote }}
{{- end }}
{{- else }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{/* Standard labels for resource metadata. */}}
{{- define "elitea.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/* Labels without app.kubernetes.io/name, for resources that set their own. */}}
{{- define "elitea.labels.common" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/* Keys that must never change after install (hmacs, auth, main): a value already stored in the cluster always wins over values.yaml, so `helm upgrade` keeps them. Otherwise empty hmacs are generated when common.secrets.hmac_auto_generate. Needs `lookup` (not available in helm template / Argo CD). */}}
{{- define "elitea.hmacs" -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (printf "%s-secret" .Values.pylon_main.name_prefix) }}
{{- range $group := list "hmacs" "auth" "main" }}
{{- $g := index $.Values.common.secrets $group }}
{{- range $k := keys $g }}
{{- if and $existing $existing.data (hasKey $existing.data $k) }}
{{- $_ := set $g $k (index $existing.data $k | b64dec) }}
{{- else if and (eq $group "hmacs") $.Values.common.secrets.hmac_auto_generate (not (index $g $k)) }}
{{- $_ := set $g $k (randAlphaNum 64) }}
{{- end }}
{{- if not (index $g $k) }}{{ fail (printf "common.secrets.%s.%s is empty: set it%s" $group $k (ternary " (or enable common.secrets.hmac_auto_generate)" "" (eq $group "hmacs"))) }}{{ end }}
{{- end }}
{{- end }}
{{- end -}}

{{/* Secret holding app credentials: common.existingSecret, else the per-service chart-managed one. */}}
{{- define "elitea.secretName" -}}
{{- include "elitea.existingSecret" .root | default (printf "%s-secret" .prefix) -}}
{{- end -}}

{{/* User-provided Secret name: common.existingSecret, or the one the chart's ExternalSecret creates. Empty = chart-managed. */}}
{{- define "elitea.existingSecret" -}}
{{- .Values.common.existingSecret | default (ternary .Values.common.externalSecret.name "" (.Values.common.externalSecret.enabled | default false)) -}}
{{- end -}}

{{/* Pod tolerations from .Values.tolerations (empty by default). Usage: {{- include "elitea.tolerations" . | nindent 6 }} */}}
{{- define "elitea.tolerations" -}}
{{- with .Values.tolerations }}
tolerations:
{{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
