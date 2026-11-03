---
# Wiki Builder Plugin Configuration
service_location_url: ${SERVICE_LOCATION_URL}

base_path: {{ .Values.pylon_deepwiki.configs.basePath }}

ai_run_platform_url: ${AI_RUN_PLATFORM_URL}
ai_run_platform_token: ${AI_RUN_PLATFORM_TOKEN}

ai_run_platform_verify: {{ .Values.pylon_deepwiki.configs.aiRunPlatform.verify }}
ai_run_platform_timeout: {{ .Values.pylon_deepwiki.configs.aiRunPlatform.timeout | int }}
ai_run_platform_delay: {{ .Values.pylon_deepwiki.configs.aiRunPlatform.delay | int }}
