{{- define "mysql.initScript" -}}
{{- range .Values.teams }}
CREATE DATABASE IF NOT EXISTS {{ .mysql.database }};
CREATE USER IF NOT EXISTS '{{ .mysql.username }}'@'%' IDENTIFIED BY '{{ .mysql.password }}';
GRANT ALL PRIVILEGES ON {{ .mysql.database }}.* TO '{{ .mysql.username }}'@'%';

CREATE RESOURCE GROUP {{ .name }}_group
  TYPE = USER
  VCPU = 1-2
  THREAD_PRIORITY = LOW
  ENABLE;

ALTER USER '{{ .mysql.username }}'@'%' RESOURCE GROUP {{ .name }}_group;

ALTER DATABASE {{ .mysql.database }}
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci
  MAX_QUERIES_PER_HOUR {{ $.Values.mysql.global.queriesPerHour }}
  MAX_UPDATES_PER_HOUR {{ $.Values.mysql.global.updatesPerHour }}
  MAX_CONNECTIONS_PER_HOUR {{ $.Values.mysql.global.connectionsPerHour }};
{{- end }}
{{- end }}

{{- define "redis.aclRules" -}}
{{- range .Values.teams }}
user {{ .name }} on >{{ .redis.password }} ~{{ .name }}:* allcommands -@dangerous
{{- end }}
user default off
{{- end }}
