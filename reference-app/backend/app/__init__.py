from flask import Flask
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry import trace
from prometheus_flask_exporter.multiprocess import GunicornInternalPrometheusMetrics
from flask_pymongo import PyMongo
import logging

_logger = logging.getLogger('backend_service')

metrics = GunicornInternalPrometheusMetrics.for_app_factory(
    defaults_prefix='backend_service', excluded_paths=['/metrics', '/health'])

mongo = PyMongo()

instrumentor = FlaskInstrumentor()
tracer = trace.get_tracer(__name__)


def create_app(env=None):
    from app.config import config_by_name
    from app.routes.index import index_bp
    from app.routes.healthchecks import healthchecks_bp
    from app.routes.apis import apis_bp
    from app.routes.stars import stars_bp

    from flask_cors import CORS
    import logging.config

    app = Flask(__name__)
    app.config.from_object(config_by_name[env or "test"])

    logging.config.dictConfig(app.config['LOGGING_CONFIG'])

    CORS(app)

    app.register_blueprint(index_bp)
    app.register_blueprint(healthchecks_bp)
    app.register_blueprint(apis_bp)
    app.register_blueprint(stars_bp)

    mongo.init_app(app)

    instrumentor.instrument_app(app)

    with app.app_context():
        from app.metrics import _init as init_metrics

        init_metrics(app)

    return app
