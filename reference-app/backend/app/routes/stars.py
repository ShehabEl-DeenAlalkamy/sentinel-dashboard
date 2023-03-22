from app import mongo, _logger

from flask import Blueprint, request, jsonify, current_app

stars_bp = Blueprint('stars_bp', __name__)


@stars_bp.route("/stars", methods=["POST"])
def create():
    _logger.info(f"Connecting to: '{current_app.config['SUPPRESSED_MONGO_URI']}'")
    star = mongo.db.stars
    name = request.json["name"]
    distance = request.json["distance"]
    star_id = star.insert({"name": name, "distance": distance})
    new_star = star.find_one({"_id": star_id})
    output = {"name": new_star["name"], "distance": new_star["distance"]}
    return jsonify({"result": output})
