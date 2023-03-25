from app import tracer, _logger

from flask import Blueprint, jsonify, request, Response
from opentelemetry.trace import set_span_in_context
from opentelemetry.trace.status import StatusCode
import json
import time
import traceback
import requests

apis_bp = Blueprint('apis_bp', __name__)


@apis_bp.route("/api", methods=["GET"])
def my_api():
    with tracer.start_as_current_span("Sleep 3 seconds"):
        time.sleep(3)
    answer = "something"
    return jsonify(repsonse=answer)


@apis_bp.route("/api/entries", methods=["GET"])
def get_public_entries():
    if request.args.get('type', None) == "public":
        homepages = []
        succeeded = False
        entries = []
        with tracer.start_span('get-public-apis') as span:
            try:
                SAMPLE_COUNT = int(request.args.get('sample', 30))
                TOTAL_COUNT = -1
                ENTRY_TIMEOUT = float(request.args.get('entry-timeout', 2.5))
                ctx = set_span_in_context(span)
                res = requests.get(
                    'https://api.publicapis.org/entries', timeout=3)
                if res.status_code == 200:
                    TOTAL_COUNT = res.json()['count']
                    _logger.info(
                        f"Received {TOTAL_COUNT} total entries")
                    _logger.info(
                        f"Collecting homepages for the first {SAMPLE_COUNT} entries to save time with timeout {ENTRY_TIMEOUT} per entry connection")
                    span.set_attribute('count.total', TOTAL_COUNT)
                    span.set_attribute('count.sample', SAMPLE_COUNT)
                    for entry in res.json()['entries'][:SAMPLE_COUNT]:
                        _logger.info(
                            f"Collecting homepage for api='{entry['API']}' category='{entry['Category']}' link='{entry['Link']}'")
                        with tracer.start_span(entry['API'], context=ctx) as api_span:
                            try:
                                homepages.append({
                                    'link': entry['Link'],
                                    'page': requests.get(entry['Link'], timeout=ENTRY_TIMEOUT)
                                })
                                entries.append(entry)
                                api_span.set_attribute('status', 'SUCCESS')
                                api_span.set_attribute(
                                    'category', entry['Category'])

                                api_span.set_attribute('cors', entry['Cors']) if entry['Cors'] else api_span.set_attribute(
                                    'cors', "N/A")
                                api_span.set_attribute('auth', entry['Auth']) if entry['Auth'] else api_span.set_attribute(
                                    'auth', "N/A")
                                api_span.set_attribute('https', entry['HTTPS'])
                            except Exception as e:
                                api_span.add_event(
                                    "exception", {"exception.message": str(e), "exception.stacktrace": traceback.format_exc()})
                                api_span.set_status(StatusCode.ERROR)
                                _logger.error(
                                    f"Error: unable to get homepage for '{entry['API']}' reason='{str(e)}'")
                                api_span.set_attribute('status', 'FAILED')
                    span.add_event("collection-success", {"homepages.count.collected": len(
                        homepages), "homepages.count.total": TOTAL_COUNT, "homepages.count.sample": SAMPLE_COUNT})
                    succeeded = True
                    _logger.info(f"Collected {len(homepages)} homepages")
                else:
                    SAMPLE_COUNT = -1
                    _logger.error(
                        f"Error: expected status code '200' got '{res.status_code}' instead")
                    _logger.info("Nothing to do..")
                    span.add_event("exception", {
                                   "exception.message": f"Error: expected status code '200' got '{res.status_code}' instead"})
                    span.set_status(StatusCode.ERROR)

            except Exception as e:
                SAMPLE_COUNT = -1
                _logger.error(f"Error: {str(e)}")
                span.add_event("exception", {"exception.message": str(
                    e), "exception.stacktrace": traceback.format_exc()})
                span.set_status(StatusCode.ERROR)

            return {
                "succeeded": succeeded,
                "results": {
                    "collected": len(homepages),
                    "sample": SAMPLE_COUNT,
                    "total": TOTAL_COUNT,
                    "entries": entries
                }
            }
    error = {
        'status_code': 400,
        'message': f"Error: Expected '?type=public' got '?type={request.args.get('type')}'"
    }
    _logger.error(error['message'])
    return Response(response=json.dumps(
        {'error': error['message']}), status=error['status_code'], mimetype='application/json')
