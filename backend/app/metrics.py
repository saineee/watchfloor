from prometheus_client import Counter, Histogram

ALERTS_INGESTED = Counter(name="alerts_ingested",
                          documentation="alerts accepted by the ingest endpoint, by whether a new alert was created, or an existing one was deduplicated.",
                          labelnames=
                          ["result"])

TRIAGE_DURATION = Histogram(name="triage_duration_seconds",
                            documentation="triage duration in seconds per alert triaged",
                            buckets=[1, 3, 4, 5, 6, 10, 30, 60])

TRIAGE_OUTCOMES = Counter(name="triage_requests",
                          documentation="triage requests by outcome: completed, skipped, or failed.",
                          labelnames=["outcome"])

for outcome in ("completed", "skipped", "failed"):
    TRIAGE_OUTCOMES.labels(outcome=outcome)

for alert_outcome in ("created", "deduped", "raced", "race_resolved"):
    ALERTS_INGESTED.labels(result=alert_outcome)
