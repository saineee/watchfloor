import json
import logging
import sys

from app.logs import CloudWatchFormatter, request_id_var, ContextVarFilter


def test_universal_fields_present_in_record():
    record = logging.makeLogRecord({"name": "application.test", "levelname": "INFO", "msg": "Hello!"})
    json_string = CloudWatchFormatter().format(record)
    parsed = json.loads(json_string)
    assert parsed["name"] == "application.test"
    assert parsed["level"] == "INFO"
    assert parsed["message"] == "Hello!"

def test_optional_fields_present_in_record():
    record = logging.makeLogRecord({"route": "/health"})
    json_string = CloudWatchFormatter().format(record)
    parsed = json.loads(json_string)
    assert parsed["route"] == "/health"
    assert "method" not in parsed

def test_traceback_fields_present_in_record():
    try:
        raise ValueError("KABOOM")
    except ValueError:
        exc_info = sys.exc_info()

    record = logging.makeLogRecord({"exc_info": exc_info})
    json_string = CloudWatchFormatter().format(record)
    parsed = json.loads(json_string)
    assert "KABOOM" in parsed["exc_info"]
    assert "ValueError" in parsed["exc_info"]

def test_contextvar_field_present_in_record():
    token = request_id_var.set("TestToken")
    record = logging.makeLogRecord({"msg": "Hello!"})
    returnVal = ContextVarFilter().filter(record)
    try:
        assert record.request_id == "TestToken"
        assert returnVal is True
    finally:
        request_id_var.reset(token)

def test_context_var_field_not_present_in_record_on_non_request():
    record = logging.makeLogRecord({"msg": "Hello!"})
    returnVal = ContextVarFilter().filter(record)
    json_string = CloudWatchFormatter().format(record)
    parsed = json.loads(json_string)
    assert returnVal is True
    assert record.request_id is None
    assert parsed["message"] == "Hello!"
    assert "request_id" not in parsed


