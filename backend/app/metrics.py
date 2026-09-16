from prometheus_client import Counter

ALERTS_INGESTED = Counter("alerts_ingested",
                          "alerts accepted by the ingest endpoint, by whether a new alert was creating, or an existing one was deduplicated.",
                          ["result"])
