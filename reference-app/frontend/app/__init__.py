from flask import Flask
from opentelemetry import trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from prometheus_flask_exporter.multiprocess import GunicornInternalPrometheusMetrics
import logging

_logger = logging.getLogger('frontend_service')
metrics = GunicornInternalPrometheusMetrics.for_app_factory(
    defaults_prefix='frontend_service', excluded_paths=['/metrics', '/health'])

flask_instrumentor = FlaskInstrumentor()
tracer = trace.get_tracer(__name__)


def create_app(env=None):
    from app.config import config_by_name
    from app.routes.index import index_bp
    from app.routes.healthchecks import healthchecks_bp

    import logging.config

    app = Flask(__name__)
    app.config.from_object(config_by_name[env or "test"])

    logging.config.dictConfig(app.config['LOGGING_CONFIG'])

    app.register_blueprint(index_bp)
    app.register_blueprint(healthchecks_bp)

    flask_instrumentor.instrument_app(app, excluded_urls="health/*,metrics")

    with app.app_context():
        from app.metrics import _init as init_metrics

        init_metrics(app)

    return app
