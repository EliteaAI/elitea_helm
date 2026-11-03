
{{- $proxy := .Values.external_proxy_enabled -}}
{{- $ca_cert := .Values.external_ca_enabled -}}
{{- $remote := (default "standard" .Values.common.elitea_repo_type) | lower -}}
{{- $addr := default "" .Values.elitea_internal_repo_address -}}
{{- $addrTrim := trim $addr -}}
{{- $repo_address := default (printf "internal-repo-svc.%s.svc.cluster.local" .Release.Namespace) $addrTrim -}}
{{- $redis_rnd_sf := .Values.redis_queue_random_suffix -}}

---

# General server config

server:
  name: ${NAME}
  path: /
  proxy:
    x_for: 1
    x_proto: 1
    x_host: 1
  host: "0.0.0.0"
  port: 8080
  # port: 8443
  # kwargs:
  #   certfile: /ssl/server.crt
  #   keyfile: /ssl/server.key
  health:
    healthz: true
    livez: true
    readyz: true

# Logging
log:
  level: {{ .Values.pylon_main.log_level | quote }}
  filters:
    - type: "centry_logging.filters.truncate_base64.Base64SanitizationFilter"
      max_base64_chars: 20

{{- if or ($proxy) ($ca_cert) }}
# SSL CAs
ssl:
  certs:
{{- range .Values.external_ca_files }}
    - /cacerts/{{ . }}
{{- end }}
{{- end }}


# Exposure

exposure:
  event_node:
    type: RedisEventNode
    host: ${REDIS_HOST}
    port: ${REDIS_PORT}
    password: ${REDIS_PASSWORD}
    event_queue: ${NAME_PREFIX}_exposure_events_{{- $redis_rnd_sf }}
    hmac_key: ${EXPOSURE_HMAC_KEY}
    hmac_digest: sha512
    callback_workers: null
    use_ssl: ${REDIS_SSL}
  handle:
    enabled: true
    prefixes:
      - /forward-auth

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
  NLTK_DATA: /data/cache/nltk
  TRANSFORMERS_CACHE: /data/cache/transformers
  TIKTOKEN_CACHE_DIR: /data/cache/tiktoken

# Persistent sessions

sessions:
  redis:
    host: ${REDIS_HOST}
    port: ${REDIS_PORT}
    password: ${REDIS_PASSWORD}
    use_ssl: ${REDIS_SSL}
  prefix: ${NAME_PREFIX}_main_session_

# Events queue

events:
  redis:
    host: ${REDIS_HOST}
    port: ${REDIS_PORT}
    password: ${REDIS_PASSWORD}
    use_ssl: ${REDIS_SSL}
    queue: ${NAME_PREFIX}_events_{{- $redis_rnd_sf }}
    hmac_key: ${EVENT_HMAC_KEY}
    hmac_digest: sha512
    callback_workers: null

# RPC

rpc:
  redis:
    host: ${REDIS_HOST}
    port: ${REDIS_PORT}
    password: ${REDIS_PASSWORD}
    use_ssl: ${REDIS_SSL}
    queue: ${NAME_PREFIX}_rpc_{{- $redis_rnd_sf }}
    hmac_key: ${RPC_HMAC_KEY}
    hmac_digest: sha512
    callback_workers: null
  id_prefix: ${NAME_PREFIX}_main_rpc_


# Settings for Flask application

application:
  SECRET_KEY: ${APPLICATION_MAIN_SECRET_KEY}
  SESSION_COOKIE_NAME: ${NAME_PREFIX}_main_session
  SESSION_COOKIE_DOMAIN: ${APP_HOST}
  SESSION_COOKIE_PATH: /
  SESSION_COOKIE_HTTPONLY: true
  SESSION_COOKIE_SECURE: ${COOKIES_SECURE}
  PERMANENT_SESSION_LIFETIME: ${COOKIES_LIFETIME}
  PREFERRED_URL_SCHEME: ${APP_PROTO}
