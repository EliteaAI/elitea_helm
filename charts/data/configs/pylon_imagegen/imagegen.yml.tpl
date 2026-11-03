---

service_location_url: ${SERVICE_LOCATION_URL}

image_bucket: {{ .Values.pylon_imagegen.configs.imageBucket | quote }}
ai_run_platform_url: ${AI_RUN_PLATFORM_URL}
ai_run_platform_token: ${AI_RUN_PLATFORM_TOKEN}


ai_run_platform_verify: {{ .Values.pylon_imagegen.configs.aiRunPlatform.verify }}
ai_run_platform_timeout: {{ .Values.pylon_imagegen.configs.aiRunPlatform.timeout | int }}
ai_run_platform_delay: {{ .Values.pylon_imagegen.configs.aiRunPlatform.delay | int }}
