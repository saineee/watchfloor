resource "aws_cloudwatch_query_definition" "requests_by_route" {
  name            = "${var.name_prefix}/requests-by-route"
  log_group_names = ["/ecs/${var.name_prefix}"]

  query_string = <<EOF
filter ispresent(route)
| stats count() as n by route, status
| sort n desc
EOF
}

resource "aws_cloudwatch_query_definition" "latency_by_route" {
  name            = "${var.name_prefix}/latency-by-route"
  log_group_names = ["/ecs/${var.name_prefix}"]

  query_string = <<EOF
filter ispresent(latency_ms)
| stats count() as n,  avg(latency_ms) as avg_ms, pct(latency_ms, 95) as p95_ms,
max(latency_ms) as max_ms by route
| sort p95_ms desc
EOF
}

resource "aws_cloudwatch_query_definition" "errors" {
  name            = "${var.name_prefix}/errors"
  log_group_names = ["/ecs/${var.name_prefix}"]

  query_string = <<EOF
filter level = "ERROR"
| stats count() as n by name, message
| sort n desc
EOF
}

resource "aws_cloudwatch_query_definition" "recent_requests" {
  name            = "${var.name_prefix}/recent-requests"
  log_group_names = ["/ecs/${var.name_prefix}"]

  query_string = <<EOF
filter ispresent(route)
| fields @timestamp, method, route, status, latency_ms, request_id
| sort @timestamp desc
| limit 50
EOF
}

resource "aws_cloudwatch_query_definition" "trace_request" {
  name            = "${var.name_prefix}/trace-request"
  log_group_names = ["/ecs/${var.name_prefix}"]

  query_string = <<EOF
filter request_id = "PASTE_REQUEST_ID"
| fields @timestamp, level, name, message, route, status, latency_ms, alert_id,
exc_info
| sort @timestamp asc
EOF
}

resource "aws_cloudwatch_query_definition" "dedup_race" {
  name            = "${var.name_prefix}/dedup-race"
  log_group_names = ["/ecs/${var.name_prefix}"]

  query_string = <<EOF
filter message in ["raced", "race_resolved"]
| stats count() as n by message, device_name, error_type
EOF
}

resource "aws_cloudwatch_query_definition" "errors_by_alert" {
  name            = "${var.name_prefix}/errors-by-alert"
  log_group_names = ["/ecs/${var.name_prefix}"]

  query_string = <<EOF
filter level = "ERROR" and ispresent(alert_id)
| stats count() as n by alert_id, message
| sort n desc
EOF
}

resource "aws_cloudwatch_query_definition" "errors_over_time" {
  name            = "${var.name_prefix}/errors-over-time"
  log_group_names = ["/ecs/${var.name_prefix}"]

  query_string = <<EOF
filter level = "ERROR"
| stats count() as n by bin(5m), message
| sort bin(5m) asc
EOF
}
