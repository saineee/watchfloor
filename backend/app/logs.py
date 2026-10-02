import json
import logging
import sys
from contextvars import ContextVar

OPTIONAL_FIELDS = ("method", "route", "status", "latency_ms", "alert_id", "request_id", "device_name", "error_type")
UVICORN_LOGGERS = ("uvicorn", "uvicorn.error")

logger = logging.getLogger()

request_id_var = ContextVar('request_id', default=None)

class CloudWatchFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            'level' : record.levelname,
            'name' : record.name,
            'message': record.getMessage(),
            'created' : record.created,
        }

        for field in OPTIONAL_FIELDS:
            value = getattr(record, field, None)
            if value is not None:
                log_record[field] = value

        if record.exc_info:
            log_record['exc_info'] = self.formatException(record.exc_info)


        return json.dumps(log_record, default=str)

class ContextVarFilter(logging.Filter):
    def filter(self, record):
        record.request_id = request_id_var.get()
        return True


def setup_logging():
    for loggername in UVICORN_LOGGERS:
        uvicornLogger = logging.getLogger(loggername)
        uvicornLogger.handlers = []
        uvicornLogger.propagate = True

    stream_handler = logging.StreamHandler(sys.stdout)

    stream_handler.addFilter(ContextVarFilter())
    stream_handler.setFormatter(CloudWatchFormatter())

    logger.addHandler(stream_handler)
    logger.setLevel(logging.INFO)

