# APIDown Runbook

## Summary
Prometheus cannot reach the API's `/metrics` endpoint. Severity: page

## Description
This alert is triggered when the `up` metric has been at a value of 0 for 2 or more continuous minutes. This alert will not fire at all when a task is not registered in Cloud Map for the reason that the `up` metric will disappear instead. `up`: Prometheus' record of whether the last scrape succeeded

## Impact
This alert could mean that the entire app stack is still technically up, but refusing scrapes from Prometheus. Monitoring will cease to work due to this including all SLO data. If the API backend is down, users will receive errors from the ALB(502/503).

## First Checks
- Step 1
