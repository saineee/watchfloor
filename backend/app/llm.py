from anthropic import AsyncAnthropic
from app.config import settings
from app.models import Alert
from app.schemas import TriageResult

client = AsyncAnthropic(
    api_key=settings.anthropic_api_key.get_secret_value()
)

async def triage(alert: Alert):
    message = await client.messages.parse(
        max_tokens=600,
        system="You are a Senior DevOps Engineer specializing in infrastructure monitoring. "
               "Analyze incoming device alerts and categorize them with strict technical accuracy "
               "according to the schema",
        messages=[{
            "role": "user",
            "content": f"""
error_type: {alert.error_type}
device_name: {alert.device_name}
device_state: {alert.device_state}
device_last_available: {alert.device_last_available}
occurrence_count: {alert.occurrence_count}
description: {alert.description}
location: {alert.location or "unknown"}
            """
        }],
        model="claude-opus-5",
        output_format=TriageResult,
        output_config={"effort":"low"}
    )

    return message.parsed_output
