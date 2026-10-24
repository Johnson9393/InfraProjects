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

{{/*
Migration Job. Runs the service migrate command against the writer before pods roll out.
*/}}
{{- define "shopsphere.migrationJob" -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "shopsphere.fullname" .root }}-{{ .component }}-migrate
  namespace: {{ include "shopsphere.namespace" .root }}
  labels:
    {{- include "shopsphere.commonLabels" .root | nindent 4 }}
    app.kubernetes.io/component: {{ .component }}-migrate
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "-10"
    helm.sh/hook-delete-policy: before-hook-creation
spec:
  ttlSecondsAfterFinished: 600
  backoffLimit: 6
  activeDeadlineSeconds: 180
  template:
    metadata:
      labels:
        {{- include "shopsphere.selectorLabels" .root | nindent 8 }}
        app.kubernetes.io/component: {{ .component }}-migrate
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: "{{ .image.repository }}:{{ .image.tag }}"
          imagePullPolicy: {{ .root.Values.global.imagePullPolicy }}
          command:
            {{- toYaml .command | nindent 12 }}
          env:
            {{- range $key, $value := .env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
            {{- range $name, $config := .secretEnv }}
            - name: {{ $name }}
              valueFrom:
                secretKeyRef:
                  name: {{ $config.secretName }}
                  key: {{ $config.secretKey }}
            {{- end }}
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 250m
              memory: 256Mi
{{- end }}

{{/*
Restart the Deployment when a Secret it uses changes (CSI/ESO refresh).
*/}}
{{- define "shopsphere.reloaderAnnotations" -}}
reloader.stakater.com/auto: "true"
{{- end }}