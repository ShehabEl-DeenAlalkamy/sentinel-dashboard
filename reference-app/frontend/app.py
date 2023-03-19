from flask import Flask, render_template, request
from prometheus_flask_exporter.multiprocess import GunicornInternalPrometheusMetrics

app = Flask(__name__)
metrics = GunicornInternalPrometheusMetrics(
    app, defaults_prefix='frontend_service')

metrics.info('app_info', 'Frontend Service',
             version='1.0.0', major='1', minor='0')


@app.route("/")
def homepage():
    return render_template("main.html")


if __name__ == "__main__":
    app.run()
