{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "newrelic-logging.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "newrelic-logging.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if ne $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}


{{/* Generate basic labels */}}
{{- define "newrelic-logging.labels" }}
app: {{ template "newrelic-logging.name" . }}
chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
heritage: {{.Release.Service }}
release: {{.Release.Name }}
app.kubernetes.io/name: {{ template "newrelic-logging.name" . }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "newrelic-logging.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
Create the name of the fluent bit config
*/}}
{{- define "newrelic-logging.fluentBitConfig" -}}
{{ template "newrelic-logging.fullname" . }}-fluent-bit-config
{{- end -}}

{{/*
Return the licenseKey
*/}}
{{- define "newrelic-logging.licenseKey" -}}
{{- if .Values.global}}
  {{- if .Values.global.licenseKey }}
      {{- .Values.global.licenseKey -}}
  {{- else -}}
      {{- .Values.licenseKey | default "" -}}
  {{- end -}}
{{- else -}}
    {{- .Values.licenseKey | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Return the cluster name
*/}}
{{- define "newrelic-logging.cluster" -}}
{{- if .Values.global}}
  {{- if .Values.global.cluster }}
    {{- .Values.global.cluster -}}
  {{- else -}}
    {{- .Values.cluster | default "" -}}
  {{- end -}}
{{- else -}}
    {{- .Values.cluster | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Return the customSecretName
*/}}
{{- define "newrelic-logging.customSecretName" -}}
{{- if .Values.global }}
  {{- if .Values.global.customSecretName }}
      {{- .Values.global.customSecretName -}}
  {{- else -}}
      {{- .Values.customSecretName | default "" -}}
  {{- end -}}
{{- else -}}
    {{- .Values.customSecretName | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Return the customSecretLicenseKey
*/}}
{{- define "newrelic-logging.customSecretKey" -}}
{{- if .Values.global }}
  {{- if .Values.global.customSecretLicenseKey }}
      {{- .Values.global.customSecretLicenseKey -}}
  {{- else -}}
    {{- if .Values.global.customSecretKey }}
        {{- .Values.global.customSecretKey -}}
    {{- else -}}
        {{- .Values.customSecretKey | default "" -}}
    {{- end -}}
  {{- end -}}
{{- else -}}
  {{- if .Values.customSecretLicenseKey }}
      {{- .Values.customSecretLicenseKey -}}
  {{- else -}}
      {{- .Values.customSecretKey | default "" -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Returns nrStaging
*/}}
{{- define "newrelic.nrStaging" -}}
{{- if .Values.global }}
  {{- if .Values.global.nrStaging }}
    {{- .Values.global.nrStaging -}}
  {{- end -}}
{{- else if .Values.nrStaging }}
  {{- .Values.nrStaging -}}
{{- end -}}
{{- end -}}

{{/*
Returns fargate
*/}}
{{- define "newrelic.fargate" -}}
{{- if .Values.global }}
  {{- if .Values.global.fargate }}
    {{- .Values.global.fargate -}}
  {{- end -}}
{{- else if .Values.fargate }}
  {{- .Values.fargate -}}
{{- end -}}
{{- end -}}

{{/*
Returns lowDataMode
*/}}
{{- define "newrelic-logging.lowDataMode" -}}
{{/* `get` will return "" (empty string) if value is not found, and the value otherwise, so we can type-assert with kindIs */}}
{{- if (get .Values "lowDataMode" | kindIs "bool") -}}
  {{- if .Values.lowDataMode -}}
    {{/*
        We want only to return when this is true, returning `false` here will template "false" (string) when doing
        an `(include "newrelic-logging.lowDataMode" .)`, which is not an "empty string" so it is `true` if it is used
        as an evaluation somewhere else.
    */}}
    {{- .Values.lowDataMode -}}
  {{- end -}}
{{- else -}}
{{/* This allows us to use `$global` as an empty dict directly in case `Values.global` does not exists */}}
{{- $global := index .Values "global" | default dict -}}
{{- if get $global "lowDataMode" | kindIs "bool" -}}
  {{- if $global.lowDataMode -}}
    {{- $global.lowDataMode -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Returns logsEndpoint
*/}}
{{- define "newrelic-logging.logsEndpoint" -}}
{{- if (include "newrelic.nrStaging" .) -}}
https://staging-log-api.newrelic.com/log/v1
{{- else if .Values.endpoint -}}
{{ .Values.endpoint -}}
{{- else if eq (substr 0 2 (include "newrelic-logging.licenseKey" .)) "eu" -}}
https://log-api.eu.newrelic.com/log/v1
{{- else -}}
https://log-api.newrelic.com/log/v1
{{- end -}}
{{- end -}}

{{/*
Returns fluentbit config to collect and forward its metrics to New Relic
*/}}
{{- define "newrelic-logging.fluentBit.monitoring.config" -}}
{{- $fluentBitMetrics := get $.Values.fluentBit "fluentBitMetrics" | default "basic" -}}
{{- if eq $fluentBitMetrics "advanced" }}
[INPUT]
    name prometheus_scrape
    Alias fb-metrics-collector
    host 127.0.0.1
    port 2020
    tag fb_metrics
    metrics_path /api/v2/metrics/prometheus
    scrape_interval 60s

[OUTPUT]
    Name                 prometheus_remote_write
    Match                fb_metrics
    Alias                fb-metrics-forwarder
    Host                 ${METRICS_HOST}
    Port                 443
    Uri                  /prometheus/v1/write?prometheus_server=${CLUSTER_NAME}
    Header               Authorization Bearer ${LICENSE_KEY}
    Tls                  On
    Tls.verify           Off
    add_label            app fluent-bit
    add_label            source kubernetes
    add_label            pod_name ${HOSTNAME}
    add_label            node_name ${NODE_NAME}
    add_label            tier  advanced
    {{- $clusterName := (include "newrelic-logging.cluster" .) -}}
    {{- if $clusterName -}}
    {{- printf "add_label            cluster_name %s" $clusterName | nindent 4 -}}
    {{- else -}}
    {{- printf "add_label            cluster_name \"%s\"" $clusterName | nindent 4 -}}
    {{- end -}}
    {{- printf "add_label            namespace %s" .Release.Namespace | nindent 4 -}}
    {{- printf "add_label            daemonset_name %s" (include "newrelic-logging.fullname" .) | nindent 4 -}}
{{- end -}}
{{- if eq $fluentBitMetrics "basic" }}
[INPUT]
    Name   dummy
    Tag    buildInfo
    Dummy  {"message":"trigger for basic metric at every 10 minutes scrape_interval"}
    Interval_Sec 600
[FILTER]
    Name    modify
    Match   buildInfo
    Add     fluentBitVersion  ${FBVERSION}
[FILTER]
    Name    lua
    Match   buildInfo
    script  /fluent-bit/scripts/payload.lua
    call    build_payload
[OUTPUT]
    Name    http
    Match   buildInfo
    Host    ${METRICS_HOST}
    Port    443
    URI     /metric/v1
    Format  json
    tls     On
    Header  Api-Key ${LICENSE_KEY}
    Header  Content-Type application/json
    json_date_key false    
{{- end -}}
{{- end -}}

{{/*
Returns metricsHost
*/}}
{{- define "newrelic-logging.metricsHost" -}}
{{- if (include "newrelic.nrStaging" .) -}}
staging-metric-api.newrelic.com
{{- else if .Values.metricsEndpoint -}}
{{ .Values.metricsEndpoint -}}
{{- else if eq (substr 0 2 (include "newrelic-logging.licenseKey" .)) "eu" -}}
metric-api.eu.newrelic.com
{{- else -}}
metric-api.newrelic.com
{{- end -}}
{{- end -}}

{{/*
Returns if the template should render, it checks if the required values are set.
*/}}
{{- define "newrelic-logging.areValuesValid" -}}
{{- $licenseKey := include "newrelic-logging.licenseKey" . -}}
{{- $customSecretName := include "newrelic-logging.customSecretName" . -}}
{{- $customSecretKey := include "newrelic-logging.customSecretKey" . -}}
{{- and (or $licenseKey (and $customSecretName $customSecretKey))}}
{{- end -}}

{{/*
If additionalEnvVariables is set, renames to extraEnv. Returns extraEnv.
*/}}
{{- define "newrelic-logging.extraEnv" -}}
{{- if .Values.fluentBit }}
  {{- if .Values.fluentBit.additionalEnvVariables }}
    {{- toYaml .Values.fluentBit.additionalEnvVariables -}}
  {{- else if .Values.fluentBit.extraEnv }}
    {{- toYaml .Values.fluentBit.extraEnv  -}}
  {{- end -}}
{{- end -}}
{{- end -}}


