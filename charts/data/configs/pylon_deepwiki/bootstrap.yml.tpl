---
{{- $remote := (default "standard" .Values.common.elitea_repo_type | lower) -}}
{{- $addr := default "" .Values.elitea_internal_repo_address -}}
{{- $addrTrim := trim $addr -}}
{{- $repo_address := default (printf "internal-repo-svc.%s.svc.cluster.local" .Release.Namespace) $addrTrim -}}
{{- $release := .Values.common.release }}
{{- $mesh := default false .Values.pylons_mesh_enabled }}
{{- $github_auth := default false .Values.common.config.github_auth }}

debug: {{ .Values.common.config.debug }}
{{- if $mesh}}
mesh:
  event_node:
    type: ZeroMQEventNode
    connect_sub: "tcp://pylon-auth-svc:5010"
    connect_push: "tcp://pylon-auth-svc:5011"
    topic: mesh
    hmac_key: ${MESH_HMAC_KEY}
    hmac_digest: sha512
    callback_workers: null
    mute_first_failed_connections: 10
    log_errors: true
{{- end }}

{{- if eq $remote "internal" }}
# Internal Bootstrap plugin configuration
plugin_repo:
  - type: repo_depot
    repo_url: {{ printf "http://%s:8080/target" $repo_address | quote }}
    release: {{ .Values.common.release }}
    license_token: internal

{{- else if eq $remote "standard" }}
# Standard Bootstrap plugin configuration
plugin_repo:
  - type: elitea_github
    release: ${ELITEA_RELEASE}
    add_source_data: false
    add_head_data: false
{{- if $github_auth}}
    license_user: $GITHUB_USER
    license_password: $GITHUB_TOKEN
{{- end }}
{{- end }}

preordered_plugins:
  - deepwiki_plugin
