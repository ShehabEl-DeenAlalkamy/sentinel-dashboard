from flask import Blueprint, jsonify

apis_bp = Blueprint('apis_bp', __name__)


@apis_bp.route("/api", methods=["GET"])
def my_api():
    answer = "something"
    return jsonify(repsonse=answer)
