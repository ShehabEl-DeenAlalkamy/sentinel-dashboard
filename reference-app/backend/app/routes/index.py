from flask import Blueprint

index_bp = Blueprint('index_bp', __name__)


@index_bp.route("/", methods=["GET"])
def index():
    return "Hello World"
