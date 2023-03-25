from app.utils import filters

from typing import List, Type
import logging
import os


class BaseConfig:
    CONFIG_NAME = "base"
    DEBUG = False

    APP_NAME = os.environ["APP_NAME"]
    APP_DESCRIPTION = os.environ["APP_DESCRIPTION"]
    APP_VERSION = os.environ["APP_VERSION"]
    APP_VERSION_MAJOR = os.environ["APP_VERSION"].split('.')[0]
    APP_VERSION_MINOR = os.environ["APP_VERSION"].split('.')[1]

    OTEL_EXPORTER_OTLP_ENDPOINT = os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"]
    OTEL_EXPORTER_OTLP_PROTOCOL = os.environ["OTEL_EXPORTER_OTLP_PROTOCOL"]

    MONGO_DB_USERNAME = os.environ["DB_USERNAME"]
    MONGO_DB_PASSWORD = os.environ["DB_PASSWORD"]
    MONGO_DB_HOST = os.environ["DB_HOST"]
    MONGO_DB_PORT = os.environ["DB_PORT"]
    MONGO_DB_NAME = os.environ["DB_NAME"]
    MONGO_AUTH_SRC = os.environ["DB_AUTH_SRC"]
    MONGO_URI = (
        f"mongodb://{MONGO_DB_USERNAME}:{MONGO_DB_PASSWORD}@{MONGO_DB_HOST}:{MONGO_DB_PORT}/{MONGO_DB_NAME}?authSource={MONGO_AUTH_SRC}"
    )
    SUPPRESSED_MONGO_URI = (
        f"mongodb://<credentials>@{MONGO_DB_HOST}{MONGO_URI.split('@' + MONGO_DB_HOST)[1]}"
    )

    LOGGING_CONFIG = {
        'version': 1,
        'disable_existing_loggers': True,
        'filters': {
            'info_lvl_filter': {
                '()': filters.SingleLevelFilter,
                'passlevel': logging.INFO,
                'reject': False
            },
            'info_lvl_filter_inverter': {
                '()': filters.SingleLevelFilter,
                'passlevel': logging.INFO,
                'reject': True
            }
        },
        'formatters': {
            'default': {
                'format': '[%(asctime)s] %(name)s [%(levelname)s] "%(message)s"',
            }
        },
        'handlers': {
            'stdout_handler': {
                'class': 'logging.StreamHandler',
                'formatter': 'default',
                'stream': 'ext://sys.stdout',
                'filters': ['info_lvl_filter']
            },
            'stderr_handler': {
                'class': 'logging.StreamHandler',
                'formatter': 'default',
                'stream': 'ext://sys.stderr',
                'filters': ['info_lvl_filter_inverter']
            },
        },
        'loggers': {
            'gunicorn.error': {
                'handlers': ['stdout_handler', 'stderr_handler'],
                'level': 'INFO',
                'propagate': False,
            },
            'gunicorn.access': {
                'handlers': ['stdout_handler', 'stderr_handler'],
                'level': 'INFO',
                'propagate': False,
            },
            'backend_service': {
                'handlers': ['stdout_handler', 'stderr_handler'],
                'level': 'INFO',
                'propagate': False,
            },
        },
        'root': {
            'level': 'INFO',
            'handlers': ['stdout_handler', 'stderr_handler'],
        }
    }


class DevelopmentConfig(BaseConfig):
    CONFIG_NAME = "dev"
    DEBUG = True
    TESTING = False


class TestingConfig(BaseConfig):
    CONFIG_NAME = "test"
    DEBUG = True
    TESTING = True


class ProductionConfig(BaseConfig):
    CONFIG_NAME = "prod"
    DEBUG = False
    TESTING = False


EXPORT_CONFIGS: List[Type[BaseConfig]] = [
    DevelopmentConfig,
    TestingConfig,
    ProductionConfig,
]

config_by_name = {cfg.CONFIG_NAME: cfg for cfg in EXPORT_CONFIGS}
