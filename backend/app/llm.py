import hashlib
from anthropic import AsyncAnthropic, WorkloadIdentityCredentials
from app.config import settings
from app.models import Alert
from app.schemas import TriageResult
import boto3

DELIMITER = "\x1f"


def get_sts_web_identity_token() -> str:
    sts = boto3.client("sts", region_name="us-east-1")
    resp = sts.get_web_identity_token(
        Audience=["https://api.anthropic.com"],
        SigningAlgorithm="RS256",
        DurationSeconds=900
    )
    return resp["WebIdentityToken"]


if settings.anthropic_api_key:
    client = AsyncAnthropic(
        api_key=settings.anthropic_api_key.get_secret_value(),
        timeout=15, max_retries=2
    )
else:
    client = AsyncAnthropic(
        credentials=WorkloadIdentityCredentials(
            identity_token_provider=get_sts_web_identity_token,
            federation_rule_id=settings.anthropic_federation_rule_id,
            organization_id=settings.anthropic_organization_id,
            service_account_id=settings.anthropic_service_account_id,
            workspace_id=settings.anthropic_workspace_id,
        ),
        timeout=15,
        max_retries=2
    )


def _triage_fields(alert: Alert):
    prompt_content = (
        f"error_type: {alert.error_type}{DELIMITER}\n"
        f"device_name: {alert.device_name}{DELIMITER}\n"
        f"device_state: {alert.device_state}{DELIMITER}\n"
        f"device_last_available: {alert.device_last_available}{DELIMITER}\n"
        f"description: {alert.description}{DELIMITER}\n"
        f"location: {alert.location or 'unknown'}{DELIMITER}\n"
    )
    return prompt_content


async def triage(alert: Alert):
    payload = _triage_fields(alert)
    llm_payload = payload + f"occurrence_count: {alert.occurrence_count}{DELIMITER}\n"
    message = await client.messages.parse(
        max_tokens=600,
        system="You are a Senior DevOps Engineer specializing in infrastructure monitoring. "
               "Analyze incoming device alerts and categorize them with strict technical accuracy "
               "according to the schema",
        messages=[{
            "role": "user",
            "content": llm_payload
        }],
        model="claude-opus-5",
        output_format=TriageResult,
        output_config={"effort": "low"}
    )

    return message.parsed_output


def hash_input(alert: Alert):
    alert_fields = _triage_fields(alert)
    alert_hash = hashlib.sha256(alert_fields.encode("utf-8")).hexdigest()
    return alert_hash
