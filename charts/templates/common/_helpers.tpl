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
{{- if kindIs "map" $v }}
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

{{/* With hmac_auto_generate, fills empty hmacs once per render, reusing the value already stored in the cluster so it stays stable across upgrades. */}}
{{- define "elitea.hmacs" -}}
{{- if .Values.hmac_auto_generate }}
{{- $h := .Values.common.secrets.hmacs }}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (printf "%s-secret" .Values.pylon_main.name_prefix) }}
{{- range $k := keys $h }}
{{- if not (index $h $k) }}
{{- if and $existing (hasKey $existing.data $k) }}
{{- $_ := set $h $k (index $existing.data $k | b64dec) }}
{{- else }}
{{- $_ := set $h $k (randAlphaNum 54) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- range $group := list "hmacs" "auth" "main" }}
{{- range $k, $v := index $.Values.common.secrets $group }}
{{- if not $v }}{{ fail (printf "common.secrets.%s.%s is empty: set it%s" $group $k (ternary " (or enable hmac_auto_generate)" "" (eq $group "hmacs"))) }}{{ end }}
{{- end }}
{{- end }}
{{- end -}}

{{/* Secret holding app credentials: common.existingSecret, else the per-service chart-managed one. */}}
{{- define "elitea.secretName" -}}
{{- .root.Values.common.existingSecret | default (printf "%s-secret" .prefix) -}}
{{- end -}}
