from flask import Flask, render_template, request
from prometheus_flask_exporter.multiprocess import GunicornInternalPrometheusMetrics
import os
import logging


app = Flask(__name__)

if __name__ != '__main__':
    gunicorn_logger = logging.getLogger('gunicorn.error')
    app.logger.handlers = gunicorn_logger.handlers
    app.logger.setLevel(gunicorn_logger.level)


metrics = GunicornInternalPrometheusMetrics(app, defaults_prefix='frontend_service')

metrics.info('app_info', 'Frontend Service',
             version='1.0.0', major='1', minor='0')


@app.route("/")
def homepage():
    return render_template("main.html")


metrics.register_default(
    metrics.counter(
        'frontend_service_http_request_by_path', 'Request count by request paths',
        labels={'path': lambda: request.path, 'method': lambda: request.method,
                'status': lambda resp: resp.status_code}
    )
)

if __name__ == "__main__":
    app.run()
