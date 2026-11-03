
{{- $proxy := .Values.external_proxy_enabled -}}
{{- $ca_cert := .Values.external_ca_enabled -}}
{{- $remote := (default "standard" .Values.common.elitea_repo_type) | lower -}}
{{- $addr := default "" .Values.elitea_internal_repo_address -}}
{{- $addrTrim := trim $addr -}}
{{- $repo_address := default (printf "internal-repo-svc.%s.svc.cluster.local" .Release.Namespace) $addrTrim -}}

---

# General server config

server:
  name: ${NAME}
  path: /
  host: "0.0.0.0"
  port: 8080
  health:
    healthz: true
    livez: true
    readyz: true

# Logging

log:
  level: {{ .Values.pylon_indexer.log_level | quote }}

{{- if or ($proxy) ($ca_cert) }}
# SSL CAs
ssl:
  certs:
{{- range .Values.external_ca_files }}
    - /cacerts/{{ . }}
{{- end }}
{{- end }}

# Pylon DB

pylon_db:
  engine_url: sqlite:////data/pylon.db

# Local paths to modules and config

modules:
  plugins:
    provider:
      type: folder
      path: /data/plugins

  requirements:
    mode: relaxed
    activation: bulk
    extra_index_url: https://download.pytorch.org/whl/cpu
    cache: /data/cache/pip
    {{- if eq $remote "internal" }}
    trusted_hosts: [ {{- $repo_address | quote }} ]
    {{- end }}
    provider:
      type: folder
      path: /data/requirements

  config:
    provider:
      type: folder
      path: /data/configs

{{- if eq $remote "standard" }}
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

# Environment configuration

environment:
  ANONYMIZED_TELEMETRY: "False"
  TOKENIZERS_PARALLELISM: "false"
  HF_HOME: /data/cache
  NLTK_DATA: /data/cache/nltk
  TRANSFORMERS_CACHE: /data/cache/transformers
  TIKTOKEN_CACHE_DIR: /data/cache/tiktoken
  AZURE_DEVOPS_CACHE_DIR: /data/cache/ado
