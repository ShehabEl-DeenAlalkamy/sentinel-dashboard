# I am referencing the image digest to ensure deterministic build
FROM python:3.8-slim@sha256:eda9e0185912dc94bf96d6571e234d12cbd49fc932de1b562bb3217bed755f83

# In production I would rather to keep some of these info confidential but there is no harm for development purposes
ENV APP_NAME backend_service
ENV APP_DESCRIPTION "Backend Service"
ENV APP_VERSION 2.3.0
# Startup command params
ENV APP_IP_ADDRESS 0.0.0.0
ENV APP_PORT 8080
ENV APP_HOME /usr/app
ENV APP_TARGET_MODULE wsgi
ENV APP_TARGET_APP app
ENV APP_WORKERS_NO 4
ENV APP_WORKERS_THREADS_NO 1
ENV APP_WORKERS_TIMEOUT 360
ENV APP_CONFIG_PATH config.py
ENV APP_ACCESS_LOG_FILE -
ENV APP_ERROR_LOG_FILE -

# ? Commented to enforce user to declare it
# ENV OTEL_EXPORTER_OTLP_ENDPOINT "http://localhost:4317"
ENV OTEL_EXPORTER_OTLP_PROTOCOL grpc
ENV OTEL_TRACES_EXPORTER otlp
ENV OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_REQUEST "Content.*,X-.*"
ENV OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_RESPONSE "Content.*,X-.*"
ENV OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SANITIZE_FIELDS ".*session.*,set-cookie,Authorization,X-Auth.*"

ENV PROMETHEUS_MULTIPROC_DIR ${APP_HOME}/metrics
ENV prometheus_multiproc_dir ${APP_HOME}/metrics

# Following least privilege principle, to ensure we don't provide root access to our container default user
RUN groupadd -g 3000 python && \
    useradd -r -u 3000 -g python python

RUN mkdir -p ${APP_HOME} && chown python:python ${APP_HOME}
WORKDIR ${APP_HOME}

# Create multi-proc metrics data store directory
RUN mkdir -p ${PROMETHEUS_MULTIPROC_DIR} && chown python:python ${PROMETHEUS_MULTIPROC_DIR}

# Making use of docker layer caching by separating the dependencies from the source code
COPY --chown=python:python requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Adding source code
COPY --chown=python:python . .

# su python
USER 3000

EXPOSE ${APP_PORT}

CMD gunicorn --access-logfile ${APP_ACCESS_LOG_FILE} --error-logfile ${APP_ERROR_LOG_FILE} -c ${APP_CONFIG_PATH} -w ${APP_WORKERS_NO} --threads ${APP_WORKERS_THREADS_NO} -t ${APP_WORKERS_TIMEOUT} -b ${APP_IP_ADDRESS}:${APP_PORT} ${APP_TARGET_MODULE}:${APP_TARGET_APP}