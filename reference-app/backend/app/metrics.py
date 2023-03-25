from app import metrics
from app.utils.helpers import get_host

from flask import request


def _init(app):
    metrics._defaults_prefix = app.config["APP_NAME"]
    metrics._default_labels = {'host': get_host()}

    metrics.init_app(app)

    metrics.info('app_info', app.config["APP_DESCRIPTION"],
                 version=app.config["APP_VERSION"], major=app.config["APP_VERSION_MAJOR"], minor=app.config["APP_VERSION_MINOR"])

    metrics.register_default(
        metrics.counter(
            f'{app.config["APP_NAME"]}_http_request_by_path', 'Request count by request paths',
            labels={'path': lambda: request.path, 'method': lambda: request.method,
                    'status': lambda resp: resp.status_code}, initial_value_when_only_static_labels=False
        )
    )
