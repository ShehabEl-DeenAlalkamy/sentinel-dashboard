from flask import Blueprint, render_template
from flask import current_app as app

index_bp = Blueprint('index_bp', __name__)


@index_bp.route("/", methods=["GET"])
def index():
    return render_template("main.html",
                           backend_svc_base_url=app.config['BACKEND_SVC_BASE_URL'],
                           trial_svc_base_url=app.config['TRIAL_SVC_BASE_URL'])
