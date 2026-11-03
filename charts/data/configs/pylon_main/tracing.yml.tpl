
{{- $redis_rnd_sf := .Values.redis_queue_random_suffix -}}
---
# Tracing Plugin Configuration

# Master switch - enable/disable all tracing
enabled: {{ .Values.tracing_enabled }}

# OTEL Collector Configuration
# All telemetry is now routed through the OTEL Collector for unified routing
otlp:
  enabled: {{ .Values.otel_collector.enabled }}
  # grpc
  endpoint: http://otel-collector-svc.{{ .Release.Namespace }}.svc.cluster.local:4317
  # http
  http_endpoint: http://otel-collector-svc.{{ .Release.Namespace }}.svc.cluster.local:4318
  insecure: true

# What to trace
instrumentation:
  http_requests: true      # Trace REST API calls
  socket_io: true          # Trace Socket.IO events
  rpc_calls: true          # Trace inter-pylon RPC calls
  database: true           # Trace DB queries
  http_client: true        # Trace outgoing HTTP requests
  logging: true            # Add trace context to logs and route through EventNode

# EventNode configuration for log routing to logging_hub
# Logs are sent through arbiter -> logging_hub -> OTEL Collector
event_node:
  type: RedisEventNode
  host: ${REDIS_HOST}
  port: ${REDIS_PORT}
  password: ${REDIS_PASSWORD}
  event_queue: ${NAME_PREFIX}_indexer_{{- $redis_rnd_sf }}
  hmac_key: ${INDEXER_HMAC_KEY}
  hmac_digest: sha512
  callback_workers: null
  mute_first_failed_connections: 10
  use_ssl: ${REDIS_SSL}

# Sampling configuration (reduce volume in production)
sampling:
  enabled: false
  rate: 1.0                # 1.0 = 100%, 0.1 = 10%

# Endpoints/paths to exclude from tracing
exclude:
  endpoints:
    - "health.check"
    - "monitoring.ping"
  paths:
    - "/health"
    - "/metrics"
    - "/favicon.ico"
    - "/static"

# Service identification
service:
  name: "pylon-main"
  environment: "production"    # development, staging, production

# Trace context header names
headers:
  trace_id: "X-Trace-ID"
  span_id: "X-Span-ID"
  parent_id: "X-Parent-ID"

# Audit Trail — persists user actions and agent tool calls to PostgreSQL
# Enable on pylon_main with mode: "writer" (DB + API)
# Enable on pylon_indexer with mode: "forwarder" (forwards via EventNode)
audit_trail:
  enabled: true
  mode: "writer"                    # "writer" or "forwarder"
  audit_all_methods: true          # If true, also audit GET requests
  skip_paths:
    - "/health"
    - "/metrics"
    - "/favicon.ico"
    - "/static"
    - "/admin/app/"
  retention_days: 90
