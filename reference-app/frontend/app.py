from flask import Flask, render_template, request
from prometheus_flask_exporter.multiprocess import GunicornInternalPrometheusMetrics
import os


def get_namespace():
    NAMESPACE_FILE = "/var/run/secrets/kubernetes.io/serviceaccount/namespace"
    namespace = os.uname()[1]
    if os.path.exists(NAMESPACE_FILE):
        with open(NAMESPACE_FILE, 'r') as file:
            namespace = file.read()
    return namespace


app = Flask(__name__)
metrics = GunicornInternalPrometheusMetrics(app, defaults_prefix='frontend_service', default_labels={
                                            'instance': os.getenv('HOSTNAME', os.uname()[1]), 'namespace': get_namespace()})

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
