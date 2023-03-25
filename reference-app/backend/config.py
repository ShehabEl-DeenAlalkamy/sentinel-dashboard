from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_flask_exporter.multiprocess import GunicornInternalPrometheusMetrics

import os


SERVICE_NAME = os.environ["APP_NAME"].replace('_', '-')
SERVICE_VERSION = os.environ["APP_VERSION"]
SERVICE_VERSION_MAJOR = os.environ["APP_VERSION"].split('.')[0]
SERVICE_VERSION_MINOR = os.environ["APP_VERSION"].split('.')[1]
OTEL_EXPORTER_OTLP_ENDPOINT = os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"]
OTEL_EXPORTER_OTLP_PROTOCOL = os.environ["OTEL_EXPORTER_OTLP_PROTOCOL"]
HOSTNAME = os.getenv('HOSTNAME', os.uname()[1])


def child_exit(server, worker):
    GunicornInternalPrometheusMetrics.mark_process_dead_on_child_exit(
        worker.pid)


def post_fork(server, worker):
    server.log.info("Worker spawned (pid: %s)", worker.pid)
    server.log.info("Starting OTLP connection with OTEL Exporter at %s using %s protocol",
                    OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_EXPORTER_OTLP_PROTOCOL)

    resource = Resource.create(
        attributes={
            "service.name": SERVICE_NAME,
            "service.namespace": "project.sentinel-dashboard",
            "service.version": SERVICE_VERSION,
            "service.version.major": SERVICE_VERSION_MAJOR,
            "service.version.minor": SERVICE_VERSION_MINOR,
            "host": HOSTNAME,
            "worker": worker.pid,
        }
    )

    trace.set_tracer_provider(TracerProvider(resource=resource))

    span_processor = BatchSpanProcessor(
        OTLPSpanExporter(endpoint=OTEL_EXPORTER_OTLP_ENDPOINT)
    )
    trace.get_tracer_provider().add_span_processor(span_processor)
