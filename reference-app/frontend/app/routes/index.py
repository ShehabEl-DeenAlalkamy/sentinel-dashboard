from app import _logger

from flask import current_app as app
from flask import Blueprint, render_template

index_bp = Blueprint('index_bp', __name__)


@index_bp.route("/", methods=["GET"])
def index():
    return render_template("main.html")
