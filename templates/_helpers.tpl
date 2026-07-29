{{/* vim: set filetype=mustache: */}}

{{- define "dashboard-cloud.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dashboard-cloud.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "dashboard-cloud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dashboard-cloud.labels" -}}
helm.sh/chart: {{ include "dashboard-cloud.chart" . }}
{{ include "dashboard-cloud.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "dashboard-cloud.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dashboard-cloud.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "dashboard-cloud.backendFullname" -}}
{{- printf "%s-backend" (include "dashboard-cloud.fullname" .) -}}
{{- end -}}

{{- define "dashboard-cloud.frontendFullname" -}}
{{- printf "%s-frontend" (include "dashboard-cloud.fullname" .) -}}
{{- end -}}

{{- define "dashboard-cloud.secretName" -}}
{{- .Values.existingSecret | default (printf "%s-app" (include "dashboard-cloud.fullname" .)) -}}
{{- end -}}

{{/* SQLAlchemy-style DSN used by the app (backend + alembic). */}}
{{- define "dashboard-cloud.databaseUrl" -}}
{{- printf "postgresql+psycopg://%s:%s@%s:%s/%s" .Values.postgres.username .Values.postgres.password .Values.postgres.host (.Values.postgres.port | toString) .Values.postgres.database -}}
{{- end -}}

{{/* Plain libpq-style DSN used by the db-init script to reach the maintenance DB. */}}
{{- define "dashboard-cloud.adminDatabaseUrl" -}}
{{- $user := .Values.postgres.admin.username | default .Values.postgres.username -}}
{{- $pass := .Values.postgres.admin.password | default .Values.postgres.password -}}
{{- printf "postgresql://%s:%s@%s:%s/%s" $user $pass .Values.postgres.host (.Values.postgres.port | toString) .Values.postgres.admin.database -}}
{{- end -}}
