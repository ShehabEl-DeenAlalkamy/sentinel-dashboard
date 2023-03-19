#!/bin/bash

export BACKEND_SVC_BASE_URL="http://localhost:8081"

FE_SVC_PATH="/Users/shehabeldeen/Documents/Personal/Courses/FWD/01.Cloud.Native.Applications.Architecture/03.Observability/project/sentinel-dashboard/reference-app/frontend"

source "${FE_SVC_PATH}"/.venv/bin/activate

# PROMETHEUS_MULTIPROC_DIR="${FE_SVC_PATH}"/metrics FLASK_APP="${FE_SVC_PATH}"/app.py flask run -p 8082
cd "${FE_SVC_PATH}" && PROMETHEUS_MULTIPROC_DIR="${FE_SVC_PATH}"/metrics gunicorn --access-logfile - --error-logfile - -c config.py -w 4 -b 0.0.0.0:8082 app:app

deactivate

rm -rf "${FE_SVC_PATH}"/metrics/*
