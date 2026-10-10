# APIDown Runbook

## Summary

Prometheus cannot reach the API's `/metrics` endpoint. Severity: page

## Description

This alert is triggered when the `up` metric has been at a value of 0 for 2 or more continuous minutes. This alert will
not fire at all when a task is not registered in Cloud Map for the reason that the `up` metric will disappear instead.
`up`: Prometheus' record of whether the last scrape succeeded

## Impact

This alert could mean that the entire app stack is still technically up, but refusing scrapes from Prometheus.
Monitoring will cease to work due to this including all SLO data. If the API backend is down, users will receive errors
from the ALB(502/503).

## Rule

**Any `terraform apply` in this runbook: Make sure you read the plan first and if it includes unrelated changes, stop
and escalate immediately**

## First Checks

Run these commands in sequential order.

```bash
ALB="$(aws elbv2 describe-load-balancers --names "watchfloor-alb" --query "LoadBalancers[0].DNSName" --output text)"
```

```bash
curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 "http://$ALB/healthz"
```

| Result | Meaning                                                                                                               | Go to                 |
|--------|-----------------------------------------------------------------------------------------------------------------------|-----------------------|
| 200    | ALB received a regular response from the API. Prometheus is not able to reach the API.                                | **Scrape Path**       |
| 502    | ALB was able to send the request to the target, but the<br/>target's response was bad or connection was refused.<br/> | **ECS**               |
| 503    | ALB does not have any healthy targets to send request to.                                                             | **ECS**               |
| 504    | ALB sent the request but timed out trying to receive a response from the API.                                         | **Networking or ECS** |
| 000    | Curl was not able to receive a response from the ALB.                                                                 | **Networking**        | 

## Scrape Path

| Hop               | Details                                                                                                             |
|-------------------|---------------------------------------------------------------------------------------------------------------------|
| 1. Config         | Check if the target is still `api.watchfloor.local:8000` located at `observability/prometheus/prometheus.yml`.      | 
| 2. Cloud Map      | Check if CloudMap still has an instance for the API server. If there is, does the ip match the running task in ECS? |
| 3. Security Group | On the API's security group: is there an 8000 inbound from Prometheus's security group?                             |
| 4. /metrics       | Does the `/metrics` endpoint still exist? Is there an auth layer on it now?                                         |

### Hop Checks

1. **Config**: Navigate to the repo and go to `observability/prometheus/prometheus.yml`. Check that the `names` key
   contains a list item with `"api.watchfloor.local"`.
   The `type` key must be `"A"` because the Cloud Map DNS record is type A. The `port` key must be `8000` as that is
   what the API container listens on. Caveat: This repo may not
   hold accurate information, for the reason that someone may have merged a configuration change, but has not run
   `terraform apply` because the automated Obs Workflow only pushes
   the new image to the repo. To diagnose, run `terraform plan` in the `/terraform` directory. See if there is a pending
   change on the Prometheus Task Definition, which would
   mean that the running config is behind `main`. To possibly remediate, review `terraform plan`, and apply only if
   every change is expected.
   If there are no findings here, move to hop 2.


2. **Cloud Map**: Run each command in sequential order.

```bash
NAMESPACE=$(aws servicediscovery list-namespaces --query "Namespaces[?Name=='watchfloor.local'].Id" --output text)
 ```  

```bash
echo "$NAMESPACE"
```

If you get nothing back, the namespace does not exist, along with all the other services on it. Hence, no reason to run
the other commands.

```bash
SVC_ID=$(aws servicediscovery list-services --filters "Name=NAMESPACE_ID,Values=$NAMESPACE" --query "Services[?Name=='api'].Id" --output text)
```   

```bash
CLOUDMAP_IP="$(aws servicediscovery list-instances --service-id "$SVC_ID" --query "Instances[].Attributes.AWS_INSTANCE_IPV4" --output text)"
```  

```bash
TASK_ARN=$(aws ecs list-tasks --cluster watchfloor-cluster --service-name watchfloor-service --query "taskArns[0]" --output text)
```

```bash
echo "$TASK_ARN"
```

**If this prints `None`, no API task is running. Go to ECS**

```bash
TASK_IP="$(aws ecs describe-tasks --cluster watchfloor-cluster --tasks "$TASK_ARN" --query "tasks[0].attachments[0].details[?name=='privateIPv4Address'].value" --output text)"
```

```bash
echo "$TASK_IP - $CLOUDMAP_IP"
```

| Output               | Meaning                                                                                         |
|----------------------|-------------------------------------------------------------------------------------------------|
| Matching             | Cloud Map is correct, move to hop 3                                                             |
| Different briefly    | Cloud Map may have an outdated cache, but should replace it with the new task within 30 seconds |
| Different persistent | Cloud Map is pointing to a dead task                                                            |
| Cloud Map IP empty   | No instance is registered, therefore Prometheus has no scrape target                            |

3. **Security Group**

| Security Group | Name                       | Relevant rule                                | 
|----------------|----------------------------|----------------------------------------------|
| API tasks      | `watchfloor-ecs-task-sg`   | Inbound 8000 from `watchfloor-prometheus-sg` |
| Prometheus     | `watchfloor-prometheus-sg` | Outbound on all IPs                          |

Run each command in sequential order.

```bash
API_SG="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=watchfloor-ecs-task-sg" --query "SecurityGroups[].GroupId" --output text)"
```

```bash
PROM_SG="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=watchfloor-prometheus-sg" --query "SecurityGroups[].GroupId" --output text)"
```

```bash
aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$API_SG" --query "SecurityGroupRules[?IsEgress==\`false\` && ReferencedGroupInfo.GroupId=='$PROM_SG'].{FromPort: FromPort, ToPort: ToPort}" --output text
```

```bash
aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$PROM_SG" --query "SecurityGroupRules[?IsEgress==\`true\` && CidrIpv4 && IpProtocol].{IpProtocol: IpProtocol, CidrIpv4: CidrIpv4}" --output text
```

| Type    | Output       | Meaning                                        | Action                                                                                                         |
|---------|--------------|------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| Ingress | 8000 8000    | The correct rules are in place for ingress     | Check Egress below                                                                                             |
| Ingress | Nothing      | The security group ingress rule does not exist | Run `terraform plan` and review, and only apply if every change is expected.                                   |
| Ingress | Other ports  | The ingress rules are incorrect                | Refer to the **Important** section below.                                                                      |
| Egress  | 0.0.0.0/0 -1 | The correct rules are in place for egress      | If both Egress on `watchfloor-prometheus-sg` and Ingress on `watchfloor-ecs-task-sg` are correct, go to hop 4  |
| Egress  | Nothing      | The security group egress rule is missing      | Refer to the **Important** section below. Note: Expect a deadman's switch alert due to the missing egress rule |

**Important**: If after running `terraform plan` in the `/terraform` directory you see that there is a change to the
security group, that is drift. Review the plan, and only apply if every change is expected. If there
are no changes after running `terraform plan`, then someone has most likely merged the wrong port on the security group.
Make sure that the `watchfloor-ecs-task-sg` is referencing `watchfloor-prometheus-sg` inbound on port 8000.
`watchfloor-prometheus-sg`
conversely should be outbound on all ports. `cidr_ipv4` should be equal to `"0.0.0.0/0"`, and ip_protocol should be
equal to `"-1"`. Prometheus needs outbound access to the API over port 8000, Alertmanager over 9093, and EFS over 2049.
The groups themselves cannot be missing here. A missing Prometheus group OR egress rule would page the deadman's switch
instead, and AWS will not allow you to delete a group attached to a running task.

4. **/metrics**
   Run these commands in sequential order.

```bash
ALB="$(aws elbv2 describe-load-balancers --names "watchfloor-alb" --query "LoadBalancers[0].DNSName" --output text)"
```

```bash
curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 "http://$ALB/metrics"
```

| Result  | Meaning                                                                                   | Action                                                                                                                                 |
|---------|-------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| 200     | The `/metrics` endpoint answers                                                           | Confirm APIDown is still firing. If so, check the Prometheus targets page for the scrape error, then escalate.                         |
| 404     | Route is deleted or moved                                                                 | A code change broke `/metrics`. Check what the last API tagged release changed, and roll back to the previous task definition revision |
| 401/403 | Auth has been added in front of the route                                                 | A code change broke `/metrics`. Check what the last API tagged release changed, and roll back to the previous task definition revision |
| 500     | Metrics collection is erroring                                                            | A code change broke `/metrics`. Check what the last API tagged release changed, and roll back to the previous task definition revision |
| 000     | Timed out, likely a metric-cardinality growth issue where too many metrics are being sent | Look at API latency and errors with the saved Log Insights queries in Cloud Watch.                                                     |

**Planned, not yet available**: Navigate to the repo and go to `/scripts`. In that folder you will find
`grafana_tunnel.sh`. Run the script from the directory using `./grafana_tunnel.sh -p` to forward to the Prometheus UI
for the targets page. Until implemented, escalate.

## Causes

1. Prometheus config changed but not applied: Hop 1
2. Cloud Map service replaced by a Terraform change: Hop 2
3. Security group rule removed or changed: Hop 3
4. `/metrics` broken by any type of code change: Hop 4
5. API task crashing or unhealthy status: ECS
6. ALB is unreachable: Networking

## ECS

### Check 1 ###

```bash
aws ecs describe-services --cluster watchfloor-cluster --services watchfloor-service --query "services[].{A_Running:runningCount, B_Desired:desiredCount}" --output text
```

| Result | Meaning                                                                       | Action                                                                                                                                                                                                                                                                                           |
|--------|-------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1/1    | ECS is fine, but ALB declares task as unhealthy                               | `TG="$(aws elbv2 describe-target-groups --query "TargetGroups[?TargetGroupName=='watchfloor-alb-tg'].TargetGroupArn" --output text)"`<br>`aws elbv2 describe-target-health --target-group-arn "$TG" --query "TargetHealthDescriptions[].TargetHealth.{State:State,Reason:Reason}" --output text` |
| 0/1    | Exec role can't pull image/App crashing/Ran out of IPs                        | Go To **Check 2 & Check 3**                                                                                                                                                                                                                                                                      |
| 0/0    | ECS desired count was set to 0, either via a Terraform change or the AWS CLI. | `terraform plan` and review, only apply if every change is expected - **Who did it**: `aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=UpdateService --max-results 5`                                                                                     |

| Target Health | Meaning                                                            |
|---------------|--------------------------------------------------------------------|
| healthy       | ALB is sending traffic                                             |
| unhealthy     | failing /healthz endpoint. See `Reason`, then checks 3 and 4.      |
| initial       | still being checked, wait about a minute                           |
| draining      | actively draining connections and is on its way out after a deploy |

### Check 2 ###

```bash
aws ecs describe-services --cluster watchfloor-cluster --services watchfloor-service --query "services[].events[:5].[createdAt,message]" --output table
```

| Result                                              | Meaning                                             | Action                                          |
|-----------------------------------------------------|-----------------------------------------------------|-------------------------------------------------|
| has reached a steady state/deployment completed     | Healthy: the deployment finished                    | Not an ECS problem, go back to **First checks** |
| was unable to place a task                          | ECS could not start the task. see the Reason        | Match the reason to **Check 3**                 |
| has started 1 tasks repeating, with no steady state | Task started, then died. Crash or health check loop | **Check 3** for the stopped reason              |
| registered 1 targets in (target-group)              | New task joined the ALB                             | No action, normal during recovery               | 

### Check 3 ###

```bash
TASKS=$(aws ecs list-tasks --cluster watchfloor-cluster --service-name watchfloor-service --desired-status STOPPED --query 'taskArns[0]' --output text)
```

```bash
echo "$TASKS"
```

**If this prints `None`, there is no stopped task. Either nothing has failed recently or it expired from ECS's
stopped-task history. See below**

```bash
aws ecs describe-tasks --cluster watchfloor-cluster --tasks "$TASKS" --query 'tasks[0].{Status:lastStatus,Code:stopCode,Reason:stoppedReason,ExitCode:containers[0].exitCode}' --output text
```

**IMPORTANT**   
ECS only holds stopped tasks for about 1 hour, so if it's gone, the evidence has expired. Fall back to the service
events and logs.  
After a fresh `terraform apply` workflow run, the API shows `CannotPullContainerError` for `:latest` until a release is
deployed. This is an expected behavior. Re-run the latest tag release.

| Result                      | Meaning                                             | Action                                                                                                                                                                                     |
|-----------------------------|-----------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| CannotPullContainerError    | Network Error/Exec role issue/Image reference issue | see **Image pull failure** below                                                                                                                                                           |
| Essential container exited  | Exit code 1: App crashed, Exit code: 137, killed    | see **Check 4** for logs                                                                                                                                                                   |
| ResourceInitializationError | Could not fetch a secret from SSM                   | see `/terraform/modules/ecs/main.tf` - `resource.aws_iam_role_policy.exec_role_ssm_policy`, make sure `ssm:GetParameters on Resources = [var.database_url_ssm_arn, var.secret_key_ssm_arn]` |

**Image pull failure**

```bash
IMAGE=$(aws ecs describe-task-definition --task-definition watchfloor-api --query "taskDefinition.containerDefinitions[0].image" --output text)
```

```bash
TAG="${IMAGE##*:}"
```

```bash
aws ecr describe-images --repository-name watchfloor-api --image-ids imageTag="$TAG"
```

| Result                                      | Meaning                                         | Action                                                                                                                                        | 
|---------------------------------------------|-------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| ImageNotFoundException                      | Tag does not exist                              | deploy a tag that exists by re-running a backend-cd workflow (newest one)                                                                     |
| Tag exists, error mentions "access denied"  | Execution role does not have the correct policy | Check execution role policy for `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer`, `ecr:GetAuthorizationToken`, and restore through Terraform |
| Tag exists, but timeout or connection issue | Task is not able to reach ECR over the network  | Check private subnets route through NAT gateway via `terraform plan`                                                                          |

### Check 4 ###

```bash
aws logs tail /ecs/watchfloor --since 30m --filter-pattern '{ $.level="ERROR" }'
```

## Networking

