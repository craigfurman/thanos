{
  local thanos = self,
  ruler+:: {
    jobPrefix: error 'must provide job prefix for Thanos Ruler alerts',
    selector: error 'must provide selector for Thanos Ruler alerts',
  },
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'thanos-ruler.rules',
        rules: [
          {
            alert: 'ThanosRulerQueueIsDroppingAlerts',
            annotations: {
              message: 'Thanos Ruler {{$labels.job}} {{$labels.pod}} is failing to queue alerts.',
            },
            expr: |||
              sum by (job) (rate(thanos_alert_queue_alerts_dropped_total{%(selector)s}[5m])) > 0
            ||| % thanos.ruler,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
          },
          {
            alert: 'ThanosRulerSenderIsFailingAlerts',
            annotations: {
              message: 'Thanos Ruler {{$labels.job}} {{$labels.pod}} is failing to send alerts to alertmanager.',
            },
            expr: |||
              sum by (job) (rate(thanos_alert_sender_alerts_dropped_total{%(selector)s}[5m])) > 0
            ||| % thanos.ruler,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
          },
          {
            alert: 'ThanosRulerHighRuleEvaluationFailures',
            annotations: {
              message: 'Thanos Ruler {{$labels.job}} {{$labels.pod}} is failing to evaluate rules.',
            },
            expr: |||
              (
                sum by (job) (rate(prometheus_rule_evaluation_failures_total{%(selector)s}[5m]))
              /
                sum by (job) (rate(prometheus_rule_evaluations_total{%(selector)s}[5m]))
              * 100 > 5
              )
            ||| % thanos.ruler,

            'for': '5m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosRulerHighRuleEvaluationWarnings',
            annotations: {
              message: 'Thanos Ruler {{$labels.job}} {{$labels.pod}} has high number of evaluation warnings.',
            },
            expr: |||
              sum by (job) (rate(thanos_rule_evaluation_with_warnings_total{%(selector)s}[5m])) > 0
            ||| % thanos.ruler,

            'for': '15m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosRulerRuleEvaluationLatencyHigh',
            annotations: {
              message: 'Thanos Ruler {{$labels.job}}/{{$labels.pod}} has higher evaluation latency than interval for {{$labels.rule_group}}.',
            },
            expr: |||
              (
                sum by (job, pod, rule_group) (prometheus_rule_group_last_duration_seconds{%(selector)s})
              >
                sum by (job, pod, rule_group) (prometheus_rule_group_interval_seconds{%(selector)s})
              )
            ||| % thanos.ruler,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosRulerGrpcErrorRate',
            annotations: {
              message: 'Thanos Ruler {{$labels.job}} is failing to handle {{ $value | humanize }}% of requests.',
            },
            expr: |||
              (
                sum by (job) (rate(grpc_server_handled_total{grpc_code=~"Unknown|ResourceExhausted|Internal|Unavailable|DataLoss|DeadlineExceeded", %(selector)s}[5m]))
              /
                sum by (job) (rate(grpc_server_started_total{%(selector)s}[5m]))
              * 100 > 5
              )
            ||| % thanos.ruler,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosRulerConfigReloadFailure',
            annotations: {
              message: 'Thanos Ruler {{$labels.job}} has not been able to reload its configuration.',
            },
            expr: 'avg(thanos_rule_config_last_reload_successful{%(selector)s}) by (job) != 1' % thanos.ruler,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosRulerQueryHighDNSFailures',
            annotations: {
              message: 'Thanos Ruler {{$labels.job}} have {{ $value | humanize }}% of failing DNS queries for query endpoints.',
            },
            expr: |||
              (
                sum by (job) (rate(thanos_ruler_query_apis_dns_failures_total{%(selector)s}[5m]))
              /
                sum by (job) (rate(thanos_ruler_query_apis_dns_lookups_total{%(selector)s}[5m]))
              * 100 > 1
              )
            ||| % thanos.ruler,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
          },
          {
            alert: 'ThanosRulerAlertmanagerHighDNSFailures',
            annotations: {
              message: 'Thanos Ruler {{$labels.job}} have {{ $value | humanize }}% of failing DNS queries for Alertmanager endpoints.',
            },
            expr: |||
              (
                sum by (job) (rate(thanos_ruler_alertmanagers_dns_failures_total{%(selector)s}[5m]))
              /
                sum by (job) (rate(thanos_ruler_alertmanagers_dns_lookups_total{%(selector)s}[5m]))
              * 100 > 1
              )
            ||| % thanos.ruler,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
          },
        ],
      },
    ],
  },
}
