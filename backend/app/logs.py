import logging

class CloudWatchFormatter(logging.formatter):
    def format(self, record):
        log_record = {
            'level' : record.levelname,
            'name' : record.name,
            'message': record.getMessage(),
            'created' : record.created,
        }

