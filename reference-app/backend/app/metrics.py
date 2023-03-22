from app import metrics
from app.utils.helpers import get_host

from flask import request


def _init(app):
    metrics._default_labels = {'host': get_host()}

    metrics.init_app(app)

    metrics.info('app_info', 'Backend Service',
                 version='2.0.1', major='2', minor='0')

    metrics.register_default(
        metrics.counter(
            'backend_service_http_request_by_path', 'Request count by request paths',
            labels={'path': lambda: request.path, 'method': lambda: request.method,
                    'status': lambda resp: resp.status_code}, initial_value_when_only_static_labels=False
        )
    )