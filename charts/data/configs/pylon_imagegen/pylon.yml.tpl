
{{- $proxy := .Values.external_proxy_enabled -}}
{{- $ca_cert := .Values.external_ca_enabled -}}
{{- $remote := (default "standard" .Values.common.elitea_repo_type) | lower -}}
{{- $addr := default "" .Values.elitea_internal_repo_address -}}
{{- $addrTrim := trim $addr -}}
{{- $repo_address := default (printf "internal-repo-svc.%s.svc.cluster.local" .Release.Namespace) $addrTrim -}}

---

# General server config
ssl:
  certs:
{{- if .Values.external_ca_enabled }}
{{- range .Values.external_ca_files }}
    - /cacerts/{{ . }}
{{- end }}
{{- end }}

server:
  name: pylon-imagegen
  path: /
  proxy:
    x_for: 1
    x_proto: 1
    x_host: 1
  host: "0.0.0.0"
  port: 8080
  health:
    healthz: true
    livez: true
    readyz: true

log:
  level: {{ .Values.pylon_imagegen.log_level | quote }}

pylon_db:
  engine_url: sqlite:////data/pylon.db

modules:
  plugins:
    provider:
      type: folder
      path: /data/plugins

  requirements:
    mode: relaxed
    activation: bulk
    cache: /data/cache/pip
    provider:
      type: folder
      path: /data/requirements

  config:
    provider:
      type: folder
      path: /data/configs

{{- if or (eq $remote "legacy") (eq $remote "standard") }}
  preload:
    bootstrap:
      provider:
        type: git
        delete_git_dir: false
        depth: null
      source: https://github.com/EliteaAI/bootstrap.git
      branch: ${ELITEA_RELEASE}
{{- else if eq $remote "internal" }}
  preload:
    bootstrap:
      provider:
        type: http_tar
      source: "http://{{ $repo_address }}:8080/target/public/depot/{{ .Values.common.release }}/plugins/bootstrap/source"
{{- end }}
