# Triage Fast Burn Runbook

## Summary

More than half of triage requests failed over the last 5 minutes, sustained for 2 minutes. Severity: page

## Description

Recording rule `slo:triage_errors:ratio_rate5m` measures the total triage requests that have failed over the past 5
minutes and divides them by the total triage requests excluding skipped.  
If `slo:triage_errors:ratio_rate5m` is greater than 0.5 for 2 minutes, this alert will fire.

Only Anthropic API errors, schema validation errors and database commit errors count as failed. Auth failures (401), missing alerts (404), and resolved alerts (409) never reach this metric.

## Impact

In the case of this alert firing, users can create, list, view, and update alerts. The triage function will return 502/503 errors. Users retrying triages can add load, and can trigger or prolong rate limiting.

## Diagram

```mermaid
---
title: Triage Endpoint
---
flowchart TD
    User[User] -->|Sends Request|Auth[Auth Layer]
    Auth -->|Logged In|Lookup[Alert Lookup]
    Lookup -->|Found Alert|Hash{Hash Changed?}
    Hash -->|Alert hash does not match|LLM[Anthropic Call]
    LLM -->|Triage response|Pydantic[Pydantic Schema Validation]
    Pydantic -->|Pydantic validation successful|Commit[DB Commit]
    Commit -->|Commit to database - Completed increment|Completed[Completed]

    Failed[Failed]
    Rejected[Rejected: Not Counted]
    Skipped[Skipped]

    Auth -->|Auth Failure 401 - not incremented|Rejected
    Lookup -->|Alert not found 404, or 409 if resolved - not incremented|Rejected
    Hash -->|Hash not changed - Skipped incremented|Skipped
    LLM -->|Anthropic rate limit/connection/etc error 5xx, 4xx - Failed incremented|Failed
    Pydantic -->|Validation Error - Failed Incremented|Failed
    Commit -->|Database Error - Failed incremented|Failed
```

## Rule

The [terraform apply rule](apidown.md#rule) from the APIDown runbook applies here as well.

## Fixes

## Disclaimer

The [Disclaimer](apidown.md#disclaimer) from the APIDown runbook applies here as well.

## Mitigation

## Verify
