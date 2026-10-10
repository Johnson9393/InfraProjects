{{/*
Return the base name of the ShopSphere chart.
*/}}
{{- define "shopsphere.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Return the fully qualified name used for Kubernetes resources.
*/}}
{{- define "shopsphere.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}


{{/*
Return the chart name and version.
*/}}
{{- define "shopsphere.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Common labels applied to ShopSphere resources.
*/}}
{{- define "shopsphere.commonLabels" -}}
helm.sh/chart: {{ include "shopsphere.chart" . }}
app.kubernetes.io/name: {{ include "shopsphere.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Return the namespace for the ShopSphere deployment.
*/}}
{{- define "shopsphere.namespace" -}}
{{- .Values.global.namespace }}
{{- end }}


{{/*
Selector labels used to identify ShopSphere workloads.
*/}}
{{- define "shopsphere.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shopsphere.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}