from flask import Flask, request, jsonify
from flask_pymongo import PyMongo
from prometheus_flask_exporter.multiprocess import GunicornInternalPrometheusMetrics
import logging
import os


def get_host():
    host = os.getenv('HOSTNAME', os.uname()[1])
    app.logger.info(f"Set 'host' label to '{host}'")
    return host


app = Flask(__name__)

if __name__ != '__main__':
    gunicorn_logger = logging.getLogger('gunicorn.error')
    app.logger.handlers = gunicorn_logger.handlers
    app.logger.setLevel(gunicorn_logger.level)

app.config["MONGO_DBNAME"] = "example-mongodb"
app.config[
    "MONGO_URI"
] = "mongodb://example-mongodb-svc.default.svc.cluster.local:27017/example-mongodb"

mongo = PyMongo(app)

metrics = GunicornInternalPrometheusMetrics(
    app, defaults_prefix='backend_service', excluded_paths=['/metrics'], default_labels={'host': get_host()})

metrics.info('app_info', 'Backend Service',
             version='1.0.0', major='1', minor='0')


@app.route("/")
def homepage():
    return "Hello World"


@app.route("/api")
def my_api():
    answer = "something"
    return jsonify(repsonse=answer)


@app.route("/star", methods=["POST"])
def add_star():
    star = mongo.db.stars
    name = request.json["name"]
    distance = request.json["distance"]
    star_id = star.insert({"name": name, "distance": distance})
    new_star = star.find_one({"_id": star_id})
    output = {"name": new_star["name"], "distance": new_star["distance"]}
    return jsonify({"result": output})


metrics.register_default(
    metrics.counter(
        'backend_service_http_request_by_path', 'Request count by request paths',
        labels={'path': lambda: request.path, 'method': lambda: request.method,
                'status': lambda resp: resp.status_code}, initial_value_when_only_static_labels=False
    )
)


if __name__ == "__main__":
    app.run()
