from app.utils import filters

from typing import List, Type
import logging
import os


class BaseConfig:
    CONFIG_NAME = "base"
    DEBUG = False
    BACKEND_SVC_BASE_URL = os.environ["BACKEND_SVC_BASE_URL"]
    TRIAL_SVC_BASE_URL = os.environ["TRIAL_SVC_BASE_URL"]
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
            'frontend_service': {
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
