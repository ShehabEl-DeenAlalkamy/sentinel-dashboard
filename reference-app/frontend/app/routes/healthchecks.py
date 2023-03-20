from app import _logger

from flask import Blueprint

healthchecks_bp = Blueprint('healthchecks_bp', __name__)


@healthchecks_bp.route("/health", methods=["GET"])
def health():
    _logger.info("Application is healthy")
    return {
        "message": "OK - healthy"
    }
