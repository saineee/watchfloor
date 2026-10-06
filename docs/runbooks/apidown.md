# APIDown Runbook

## Summary
Prometheus cannot reach the API's `/metrics` endpoint. Severity: page

## Description
This alert is triggered when the `up` metric has been at a value of 0 for 2 or more continuous minutes. This alert will not fire at all when a task is not registered in Cloud Map for the reason that the `up` metric will disappear instead. `up`: Prometheus' record of whether the last scrape succeeded

## Impact
This alert could mean that the entire app stack is still technically up, but refusing scrapes from Prometheus. Monitoring will cease to work due to this including all SLO data. If the API backend is down, users will receive errors from the ALB(502/503).

## First Checks
Run these commands in your CLI.

```bash
ALB="$(aws elbv2 describe-load-balancers --names "watchfloor-alb" --query "LoadBalancers[0].DNSName" --output text)"
curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 "http://$ALB/healthz"
```

| Result | Means                                                                                                                 | Go to                 |
|--------|-----------------------------------------------------------------------------------------------------------------------|-----------------------|
| 200    | ALB received a regular response from the API. Prometheus is not able to reach the API.                                | **Scrape Path**       |
| 502    | ALB was able to send the request to the target, but the<br/>target's response was bad or connection was refused.<br/> | **ECS**               |
| 503    | ALB does not have any healthy targets to send request to.                                                             | **ECS**               |
| 504    | ALB sent the request but timed out trying to receive a response from the API.                                         | **Networking or ECS** |
| 000    | Curl was not able to receive a response from the ALB.                                                                 | **Networking**        | 

## Scrape Path
| Hop       | Details                                                                                                             |
|-----------|---------------------------------------------------------------------------------------------------------------------|
| 1. Config | Check if the target is still `api.watchfloor.local:8000` located at `observability/prometheus/prometheus.yml`.       | 
| 2. Cloud Map | Check if CloudMap still has an instance for the API server. If there is, does the ip match the running task in ECS? |
| 3. Security Group | On the API's security group: is there an 8000 inbound from Prometheus's security group?                             |
| 4. /metrics | Does the `/metrics` endpoint still exist? Is there an auth layer on it now?                                         |

### Hop Checks
1. **Config**: Navigate to the repo and go to `observability/prometheus/prometheus.yml`. Check that the `names` key contains a list item with `"api.watchfloor.local"`. 
The `type` key must be `"A"` because the Cloud Map DNS record is type A. The `port` key must be `8000` as that is what the API container listens on. Caveat: This repo may not
hold accurate information, for the reason that someone may have merged a configuration change, but has not run `terraform apply` because the automated Obs Workflow only pushes 
the new image to the repo. To diagnose, run `terraform plan` in the `/terraform` directory. See if there is a pending change on the Prometheus Task Definition, which would 
mean that the running config is behind `main`. To possibly remediate, run `terraform apply` followed with `yes`, however this may not contain just the Task Definition change if there were other commits made.  
If there are no findings here, move to hop 2.


2. **Cloud Map**: Run each command in sequential order.
```bash
NAMESPACE=$(aws servicediscovery list-namespaces --query "Namespaces[?Name=='watchfloor.local'].Id" --output text)
 ```  
```bash
echo "$NAMESPACE"
```
If you get nothing back, the namespace does not exist, along with all the other services on it. Hence, no reason to run the other commands.

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
TASK_IP="$(aws ecs describe-tasks --cluster watchfloor-cluster --tasks "$TASK_ARN" --query "tasks[0].attachments[0].details[?name=='privateIPv4Address'].value" --output text)"
```
```bash
echo "$TASK_IP - $CLOUDMAP_IP"
```
| Output            | Meaning |
|-------------------| ------- |
| Matching          | Cloud Map is correct, move to hop 3 |
| Different briefly | Cloud Map may have an oudated cache, but should replace it with the new task within 30 seconds |
|  Different persistent | Cloud Map is pointing to a dead task |
| Cloud Map IP empty | No instance is registered, therefore Prometheus has no scrape target |

3. **Security Group**

| Security Group | Name | Relevant rule | 
|----------------| ---- | ------------- |
| API tasks      | `watchfloor-ecs-task-sg` | Inbound 8000 from `watchfloor-prometheus-sg`|
| Prometheus     | `watchfloor-prometheus-sg` | Outbound on all IPs |


Run each command in sequential order.  
```bash
API_SG="$(aws ec2 describe-security-groups --filters "Name='group-name',Values='watchfloor-ecs-task-sg'" --query "SecurityGroups[].GroupId" --output text)"
```
```bash
PROM_SG="$(aws ec2 describe-security-groups --filters "Name='group-name',Values='watchfloor-prometheus-sg'" --query "SecurityGroups[].GroupId" --output text)"
```
```bash
aws ec2 describe-security-group-rules --filters "Name='group-id',Values=$API_SG"
```
```bash
aws ec2 describe-security-group-rules --filters Name=group-id,Values=$API_SG --query "SecurityGroupRules[?ReferencedGroupInfo.GroupId=='$PROM_SG'].{FromPort: FromPort, ToPort: ToPort}" --output text
```
