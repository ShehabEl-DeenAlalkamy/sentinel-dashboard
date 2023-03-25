#!/bin/bash

# export BACKEND_SVC_BASE_URL="http://hamada.backend.com:8081"
# export TRIAL_SVC_BASE_URL="http://hamada.trial.com:8080"
# export APP_METRICS_SERVER_PORT="8091"

export DB_USERNAME='hamada'
export DB_PASSWORD='wowimsosecure'
export DB_HOST=localhost
export DB_PORT=30008
export DB_NAME=galaxydb
export DB_AUTH_SRC='admin'

export APP_NAME=backend_service
export APP_DESCRIPTION="Backend Service"
export APP_VERSION=2.1.0
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_REQUEST="Content.*,X-.*"
export OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_RESPONSE="Content.*,X-.*"
export OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SANITIZE_FIELDS=".*session.*,set-cookie,Authorization,X-Auth.*"
export OTEL_TRACES_EXPORTER=otlp
# export OTEL_RESOURCE_ATTRIBUTES="service.name=backend-service"

# prometheus-mongodb-exporter
# MONGO_URI="mongodb://hamada:wowimsosecure@mongodb.default:27017/stars?authSource=admin"
# helm install prometheus-mongodb-exporter \
#    --set serviceMonitor.enabled=true,serviceMonitor.namespace=monitoring,serviceMonitor.additionalLabels.release="prometheus",mongodb.uri="${MONGO_URI}" \
#    prometheus-community/prometheus-mongodb-exporter

FE_SVC_PATH="/Users/shehabeldeen/Documents/Personal/Courses/FWD/01.Cloud.Native.Applications.Architecture/03.Observability/project/sentinel-dashboard/reference-app/frontend"
BE_SVC_PATH="/Users/shehabeldeen/Documents/Personal/Courses/FWD/01.Cloud.Native.Applications.Architecture/03.Observability/project/sentinel-dashboard/reference-app/backend"

# source "${FE_SVC_PATH}"/.venv/bin/activate
source "${BE_SVC_PATH}"/.venv/bin/activate

# export DEBUG_METRICS=false

# PROMETHEUS_MULTIPROC_DIR="${FE_SVC_PATH}"/metrics FLASK_APP="${FE_SVC_PATH}"/app.py flask run -p 8082
# cd "${FE_SVC_PATH}" && PROMETHEUS_MULTIPROC_DIR="${FE_SVC_PATH}"/metrics gunicorn --access-logfile - --error-logfile - -c config.py -w 4 --threads 2 -b 0.0.0.0:8082 wsgi:app
cd "${BE_SVC_PATH}" && PROMETHEUS_MULTIPROC_DIR="${BE_SVC_PATH}"/metrics gunicorn --access-logfile - --error-logfile - -c config.py -t 360 -w 4 --threads 0 -b 0.0.0.0:8083 wsgi:app

deactivate

# rm -rf "${FE_SVC_PATH}"/metrics/*
rm -rf "${BE_SVC_PATH}"/metrics/*

# autopep8 dependencies
#autopep8==2.0.2
#pycodestyle==2.10.0
#tomli==2.0.1

# BE_SVC functional testing:
# curl "http://localhost:8083/?[1-5]"\; curl "http://localhost:8083/undefined/endpoint[1-5]"; curl -X POST "http://localhost:8083/?[1-5]"; curl "http://localhost:8083/api?[1-5]"; curl -X POST "http://localhost:8083/star?[1-2]" -H 'Content-Type: application/json' -d '{ "name": "Proxima", "distance": "1.2 parsec" }'
