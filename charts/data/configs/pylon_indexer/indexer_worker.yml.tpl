---
nltk_data: /data/cache/nltk
parallel_subagent_dispatch: true
tasknode_tmp: /data/cache/tasknode

agent_memory_config:
  type: postgres
  connection_string: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/agentstate
  connection_kwargs:
    autocommit: true

{{- if eq .Values.cloud_pgsql_type "azure" }}
pgvector_create_extension: false
{{- end }}

reasoning_in_body_for:
  - global.openai.gpt-5.6
  - global.openai.gpt-6

env_vars:
  SANDBOX_TIMEOUT_SECONDS: "${SANDBOX_TIMEOUT_SECONDS}"
