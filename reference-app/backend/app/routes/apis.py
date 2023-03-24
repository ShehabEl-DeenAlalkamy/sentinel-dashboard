from app import tracer

from flask import Blueprint, jsonify
import time

apis_bp = Blueprint('apis_bp', __name__)


@apis_bp.route("/api", methods=["GET"])
def my_api():
    with tracer.start_as_current_span("Sleep 3 seconds"):
        time.sleep(3)
    answer = "something"
    return jsonify(repsonse=answer)
