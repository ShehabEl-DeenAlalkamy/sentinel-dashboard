from app import metrics

from flask import request


def _init(app):
    metrics.init_app(app)

    metrics.info('app_info', 'Frontend Service',
                 version='2.0.0', major='2', minor='0')

    metrics.register_default(
        metrics.counter(
            'frontend_service_http_request_by_path', 'Request count by request paths',
            labels={'path': lambda: request.path, 'method': lambda: request.method,
                    'status': lambda resp: resp.status_code}, initial_value_when_only_static_labels=False
        )
    )
