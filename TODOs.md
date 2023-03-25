<!-- markdownlint-configure-file {
  "MD033": false,
  "MD041": false
} -->

# Submission TODO List

**Note:** For the screenshots, you can store all of your answer images in the `answer-img` directory.

> :memo: **Personal Note:** I am storing all of my project screenshots in `docs/assets/imgs` directory

## Verify the monitoring installation

1- run `kubectl` command to show the running pods and services for all components. Take a screenshot of the output and include it here to verify the installation

<details>

<summary>Answer</summary>

<div align="center">

![Local kubectl, check workloads][installation-local-kubectl-check-workloads-01]

![Local kubectl, check workloads][installation-local-kubectl-check-workloads-03]

</div>

</details>

## Setup the Jaeger and Prometheus source

2- Expose Grafana to the internet and then setup Prometheus as a data source. Provide a screenshot of the home page after logging into Grafana.

<details>

<summary>Answer</summary>

<div align="center">

![Grafana Home Page][installation-grafana-home]
_I am automatically exposing `Grafana` via `NodePort` as part of the environment setup in `vagrant up` command_

</div>

<div align="center">

![Grafana Datasources Page][installation-grafana-datasources]
_Jaeger datasource has been automatically configured as a datasource as part of the environment setup in `vagrant up` command_

</div>

<div align="center">

![Jaeger Datasource Configuration Page][installation-grafana-jaeger-datasource]

</div>

</details>

## Create a Basic Dashboard

3- Create a dashboard in Grafana that shows Prometheus as a source. Take a screenshot and include it here.

<details>

<summary>Answer</summary>

<div align="center">

![My Custom Dashboard][my-basic-dashboard]

![My Custom Dashboard - Instance Load per CPU][my-basic-dashboard-datasource]

</div>

</details>

## Describe SLO/SLI

4- Describe, in your own words, what the SLIs are, based on an SLO of _monthly uptime_ and _request response time_.

<details>

<summary>Answer</summary>

### Overview

&nbsp;&nbsp;&nbsp;&nbsp;**SLI** is a service level indicator—a carefully defined quantitative measure of some aspect of the level of service that is provided. It is often expressed in terms of ratio of a measurement to a given amount of time.

&nbsp;&nbsp;&nbsp;&nbsp;**SLO** is a service level objective: a target value or range of values for a service level that is measured by an **SLI**. A natural structure for SLOs is thus `SLI ≤ target`, or `lower bound ≤ SLI ≤ upper bound`.

### Examples

1. `monthly uptime` indicates that how much available your service is _in other words, working properly upon request_ during a month. A typical SLO would go like; `99.999% of reponses will be with status codes of 2xx per month`, SLI would be the actual measurement of responses status codes during a given month then compared with the SLO to indicate the current performance and induce insights and decisions on what to do next to improve the performance.
2. `request response time` indicates the time taken to return with a response for a given request. A typical SLO would go like; `99.95% of incoming requests will be processed under 150ms per month`. SLI would be the actual measurement of difference between response/request timestamps during a given month then compared with the SLO to indicate the current performance and induce insights and decisions on what to do next to improve the performance.

</details>

## Creating SLI metrics

5- It is important to know why we want to measure certain metrics for our customer. Describe in detail 5 metrics to measure these SLIs.

<details>

<summary>Answer</summary>

<table>
    <tr align="center" style="font-size: 18px;">
        <td><strong>Improvement Aspect</strong></td>
        <td><strong>SLO</strong></td>
        <td><strong>SLI Metrics</strong></td>
    </tr>
    <tr>
        <td align="center" style="font-size: 18px;"><strong>Uptime</strong></td>
        <td>99.99% of all HTTP statuses will be 20x per month</td>
        <td><ul><li><strong>Downtime duration:</strong> the time for which the system is down</li><li><strong>Downtime frequency:</strong> how often the system is down</li><li><strong>Uptime:</strong> the fraction of the time that a service is usable<li><strong>Error rate:</strong> the quantity of errors that occur within a given timeframe</li></ul></td>
    </tr>
    <tr>
        <td align="center" style="font-size: 18px;"><strong>Request/Response Time</strong></td>
        <td>99.95% of all requests will take less than 150ms per month</td>
        <td><ul><li><strong>Latency:</strong> how long it takes for the system to process a request</li><li><strong>Saturation:</strong> the network and server resources loads</li><li><strong>Network capacity</strong></li></ul></td>
    </tr>
</table>

</details>

## Create a Dashboard to measure our SLIs

6- Create a dashboard to measure the uptime of the frontend and backend services We will also want to measure to measure 40x and 50x errors. Create a dashboard that show these values over a 24 hour period and take a screenshot.

<details>

<summary>Answer</summary>

I named my project `sentinel-dashboard` and hence the dashboard name:

<div align="center">

![Initial Sentinel Dashboard, 24 Hrs Period][initial-sentinel-dashboard-24h-period]
_Over 24 hour period_

![Initial Sentinel Dashboard - 30 Mins Period][initial-sentinel-dashboard-30m-period]
_Over 24 hour period_

> :memo: **Note:** in `5XX Errors per second` panel, there is no `frontend` in the legend as there were no endpoints that can cause such scenario but if there was it will be plotted here.

</div>

</details>

## Tracing our Flask App

7- We will create a Jaeger span to measure the processes on the backend. Once you fill in the span, provide a screenshot of it here. Also provide a (screenshot) sample Python file containing a trace and span code used to perform Jaeger traces on the backend service.

<details>

<summary>Answer</summary>

I instrumented both of `frontend` and `backend` applications using `OTEL` and exported them using `OTLP` to follow the new standards as [Jaeger clients are no longer supported][jaeger-clients-deprication-announcement].

### Frontend Service

<div align="center">

![Jaeger Query, frontend-service 01][jaeger-query-fe-svc-01]

![Jaeger Query, frontend-service 02][jaeger-query-fe-svc-02]
_I added the current host of the request received as a process attribute and added best practices [Resource Semantic Conventions Attributes][otel-res-semantic-convention] as well_

</div>

### Backend Service

<div align="center">

![Jaeger Query, backend-service 01][jaeger-query-be-svc-01]

![Jaeger Query, backend-service 02][jaeger-query-be-svc-02]

</div>

> :memo: **Note:** Both of `frontend-service` and `backend-service` have been configured to ignore `/health` and `/metrics` endpoints following best practices.

`sentinel-dashboard` project has been configured such that traces mask sensitive headers including `Authorization` and `X-Authorization` to mask secrets from logs:

<div align="center">

![Jaeger Query, Redacted Headers 01][jaeger-query-be-svc-redacted-headers-01]

![Jaeger Query, Redacted Headers 02][jaeger-query-be-svc-redacted-headers-02]

</div>

Additionally, I developed a new endpoint in `backend` application; `/api/entries?type=public&sample=<sample_no:int>&entry-timeout=<timeout:float>` to get public apis info; the credit goes to [public-apis][public-apis] for their amazing API, I just developed this for fun and manually writing spans as can be seen down below:

<div align="center">

![Get Public APIs 01][jaeger-query-be-svc-api-entries-api-01]

![Get Public APIs 02][jaeger-query-be-svc-api-entries-api-02]

![Jaeger Query, API Entries 01][jaeger-query-be-svc-api-entries-timeline-graph]

![Jaeger Query, API Entries 02][jaeger-query-be-svc-api-entries-trace-graph]

![Jaeger Query, API Entries 03][jaeger-query-be-svc-api-entries-collection-success]
_I added a `collection-success` event on success and you can see the same results in the API call_

![Jaeger Query, API Entries 04][jaeger-query-be-svc-api-entries-exception]
_I added `exception` event on fetch failures when retries exceeds `entry-timeout` provided query param and added the stacktrace as well to follow best practices_

</div>

### Python Code

#### I. Auto-instrumentation

I auto-instrumented my `Flask Application` using `opentelemetry.instrumentation.flask.FlaskInstrumentor` and auto-instrumented `PyMongo` using `opentelemetry.instrumentation.pymongo.PymongoInstrumentor`, a sample of the code can be seen below:

```python

...output ommitted

from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.pymongo import PymongoInstrumentor

...output ommitted

pymongo_instrumentor = PymongoInstrumentor()
flask_instrumentor = FlaskInstrumentor()

...output ommitted


def create_app(env=None):
    ...output ommitted

    pymongo_instrumentor.instrument()

    mongo.init_app(app)

    flask_instrumentor.instrument_app(app, excluded_urls="health/*,metrics")

    ...output ommitted

    return app
```

> :bulb: **Tip:** Full code can be seen [here][auto-instrumentation].

#### II. Manual-instrumentation

This is the code used for `/api/entries` endpoint:

```python
from app import tracer, _logger

from flask import Blueprint, jsonify, request, Response
from opentelemetry.trace import set_span_in_context
from opentelemetry.trace.status import StatusCode
import json
import traceback
import requests

apis_bp = Blueprint('apis_bp', __name__)

...output ommitted

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
```

</details>

## Jaeger in Dashboards

8- Now that the trace is running, let's add the metric to our current Grafana dashboard. Once this is completed, provide a screenshot of it here.

<details>

<summary>Answer</summary>

Since Jaeger is used to give insights about requests duration out of the box we can use it to get hints about the latency of both of `frontend` and `backend` applications:

<div align="center">

![Grafana Panel, Jaeger Datasource, frontend][grafana-jaeger-datasource-panel]

![Sentinel Dashboard, 24 Hrs period, Latency Added][sentinel-dashboard-latency]

</div>

</details>

## Report Error

9- Using the template below, write a trouble ticket for the developers, to explain the errors that you are seeing (400, 500, latency) and to let them know the file that is causing the issue also include a screenshot of the tracer span to demonstrate how we can user a tracer to locate errors easily.

<details>

<summary>Answer</summary>

TROUBLE TICKET

**Name:** hamada.the.backend-developer@company.com

**Date:** October 25 2023

**Subject:** Database Connection Failure

**Affected Area:** backend-service

**Severity:** `CRITICAL`

**Description:** backend-service `/stars` endpoint fails and returns `5XX error` due to database connection error, please find the attached exception stacktrace.

<div align="center">

![Jaeger Query, /stars stacktrace][jaeger-query-be-svc-stars-stacktrace]

</div>

### Developer Solution

`backend-service` lacks database availability and hence a `mongodb.yaml` manifest has been added and `backend-service` has been properly configured to authenticate and populate `galaxydb` with stars documents in the future:

<div align="center">

![/stars API call][jaeger-query-be-svc-stars-success-api]

![Jaeger Query, /stars Timeline Trace][jaeger-query-be-svc-stars-success-trace]
_Notice that `backend-service` has been auto-instrumented using `OTEL` PyMongo instrumentor_

![Jaeger Query, /stars Trace Graph][jaeger-query-be-svc-stars-success-trace-graph]

</div>

</details>

## Creating SLIs and SLOs

10- We want to create an SLO guaranteeing that our application has a 99.95% uptime per month. Name four SLIs that you would use to measure the success of this SLO.

<details>

<summary>Answer</summary>

- **Error rate:** the quantity of errors that occur within a given timeframe
- **Uptime:** the fraction of the time that a service is usable
- **Latency:** how long it takes for the system to process a request
- **Saturation:** the network and server resources loads

</details>

## Building KPIs for our plan

11- Now that we have our SLIs and SLOs, create a list of 2-3 KPIs to accurately measure these metrics as well as a description of why those KPIs were chosen. We will make a dashboard for this, but first write them down here.

<details>

<summary>Answer</summary>

1. The average 20x or 30x responses of the web application for the month of March 2023 is 97.99%.
   - Monthly uptime - this KPI indicates the total usability of the application.
   - 20x code responses per month - this KPI indicates availability of the pages of the application.
   - Monthly traffic - this KPI will indicate the number of requests served by the application.
2. 1.5% of the total incoming requests had 50x responses for the month of March 2023.
   - Monthly downtime - this KPI indicates the number of times the application was down
   - Errors per month - this KPI will indicate the monthly errors encountered in the application.
   - Monthly traffic - this KPI will indicate the number of requests served by the application.
3. It took an average of 1070 ms for incoming requests to be served for the month of March 2023.
   - Average monthly latency - this KPI will indicate the time it took for the application to respond to requests.
   - Monthly uptime - this KPI indicates the total usability of the application.
   - Monthly traffic - this KPI will indicate the number of requests served by the application.
4. The average CPU usage of the application is 42.65% for the month of March 2023.
   - Average monthly CPU usage of pod used by the application - this KPI will indicate how much CPU is used by the source pod of the application.
   - Average monthly CPU usage of all the pods - this KPI will indicate how much CPU is used by all the pods required to run the application.
   - Monthly quota limit - this KPI will indicate whether the application is exceeding its usage of the CPU quota.
5. The average memory usage of the application is 300Mib for the month of March 2023.
   - Average monthly memory usage of pod used by the application - this KPI will indicate how much memory is used by the source pod of the application.
   - Average monthly memory usage of all the pods - this KPI will indicate how much memory is used by all the pods required to run the application.
   - Monthly quota limit - this KPI will indicate whether the application is exceeding its usage of the memory quota.

</details>

## Final Dashboard

12- Create a Dashboard containing graphs that capture all the metrics of your KPIs and adequately representing your SLIs and SLOs. Include a screenshot of the dashboard here, and write a text description of what graphs are represented in the dashboard.

<details>

<summary>Answer</summary>

<div align="center">

![Sentinel Dashboard Final 01][sentinel-dashboard-final-01]

![Sentinel Dashboard Final 02][sentinel-dashboard-final-02]

![Sentinel Dashboard Final 03][sentinel-dashboard-final-03]

</div>

### Description

- **Uptime:** Indicates that how much available frontend and backend are _in other words, working properly upon request_ during a month
- **State:** Indicates whether services are available for requests or not.
- **CPU Usage:** It represents rate of increase of CPU usage per 1 minute.
- **Memory Usage:** It represents rate of increase of memory usage per 1 minute.
- **Latency:** Represents the 99th precentile of the request duration.
- **Error Rate:** Represents the rate of increase of 4XX and 5XX responses per 30s.
- **Requests Rate:** Represents the rate of increase of 2XX responses per 30s.
- **Total Requests per minute:** Represents the rate of increase of all responses codes per 1m.
- **Average Response Time:** Represents the rate of increase of total requests durations in seconds divided by the rate of increase total number of seconds per 30 seconds for all 2XX responses grouped by path.

</details>

<!--*********************  R E F E R E N C E S  *********************-->

<!-- * Links * -->

[jaeger-clients-deprication-announcement]: https://github.com/jaegertracing/jaeger/issues/3362
[otel-res-semantic-convention]: https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/resource/semantic_conventions/README.md#resource-semantic-conventions
[public-apis]: https://github.com/public-apis/public-apis
[auto-instrumentation]: ./reference-app/backend/app/__init__.py

<!-- * Images * -->

[installation-local-kubectl-check-workloads-01]: ./docs/assets/imgs/installation-local-kubectl-check-workloads-01.png
[installation-local-kubectl-check-workloads-03]: ./docs/assets/imgs/installation-local-kubectl-check-workloads-03.png
[installation-grafana-home]: ./docs/assets/imgs/installation-grafana-home-page.png
[installation-grafana-datasources]: ./docs/assets/imgs/installation-grafana-datasources.png
[installation-grafana-jaeger-datasource]: ./docs/assets/imgs/installation-grafana-jaeger-datasource.png
[my-basic-dashboard]: ./docs/assets/imgs/my-basic-custom-dashboard.png
[my-basic-dashboard-datasource]: ./docs/assets/imgs/my-basic-custom-dashboard-datasource.png
[initial-sentinel-dashboard-24h-period]: ./docs/assets/imgs/initial-sentinel-dashboard-24h-period.png
[initial-sentinel-dashboard-30m-period]: ./docs/assets/imgs/initial-sentinel-dashboard-30m-period.png
[jaeger-query-fe-svc-01]: ./docs/assets/imgs/jaeger-query-fe-svc-01.png
[jaeger-query-fe-svc-02]: ./docs/assets/imgs/jaeger-query-fe-svc-02.png
[jaeger-query-be-svc-01]: ./docs/assets/imgs/jaeger-query-be-svc-01.png
[jaeger-query-be-svc-02]: ./docs/assets/imgs/jaeger-query-be-svc-02.png
[jaeger-query-be-svc-redacted-headers-01]: ./docs/assets/imgs/jaeger-query-be-svc-redacted-headers-01.png
[jaeger-query-be-svc-redacted-headers-02]: ./docs/assets/imgs/jaeger-query-be-svc-redacted-headers-02.png
[jaeger-query-be-svc-api-entries-api-01]: ./docs/assets/imgs/jaeger-query-be-svc-api-entries-api-01.png
[jaeger-query-be-svc-api-entries-api-02]: ./docs/assets/imgs/jaeger-query-be-svc-api-entries-api-02.png
[jaeger-query-be-svc-api-entries-timeline-graph]: ./docs/assets/imgs/jaeger-query-be-svc-api-entries-timeline-graph.png
[jaeger-query-be-svc-api-entries-trace-graph]: ./docs/assets/imgs/jaeger-query-be-svc-api-entries-trace-graph.png
[jaeger-query-be-svc-api-entries-collection-success]: ./docs/assets/imgs/jaeger-query-be-svc-api-entries-collection-success.png
[jaeger-query-be-svc-api-entries-exception]: ./docs/assets/imgs/jaeger-query-be-svc-api-entries-exception.png
[grafana-jaeger-datasource-panel]: ./docs/assets/imgs/grafana-jaeger-datasource-panel.png
[sentinel-dashboard-latency]: ./docs/assets/imgs/sentinel-dashboard-latency.png
[jaeger-query-be-svc-stars-stacktrace]: ./docs/assets/imgs/jaeger-query-be-svc-stars-stacktrace.png
[jaeger-query-be-svc-stars-success-api]: ./docs/assets/imgs/jaeger-query-be-svc-stars-success-api.png
[jaeger-query-be-svc-stars-success-trace]: ./docs/assets/imgs/jaeger-query-be-svc-stars-success-trace.png
[jaeger-query-be-svc-stars-success-trace-graph]: ./docs/assets/imgs/jaeger-query-be-svc-stars-success-trace-graph.png
[sentinel-dashboard-final-01]: ./docs/assets/imgs/sentinel-dashboard-final-01.png
[sentinel-dashboard-final-02]: ./docs/assets/imgs/sentinel-dashboard-final-02.png
[sentinel-dashboard-final-03]: ./docs/assets/imgs/sentinel-dashboard-final-03.png
