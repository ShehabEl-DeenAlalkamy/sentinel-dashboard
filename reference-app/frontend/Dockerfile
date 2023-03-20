# I am referencing the image digest to ensure deterministic build
FROM python:3.8-alpine@sha256:9e8a162cd85c78458ac47457b08450be8ca4ae5de5ee0f7b23665b6ea2569aed

# In production I would rather to keep some of these info confidential but there is no harm for development purposes
ENV APP_IP_ADDRESS 0.0.0.0
ENV APP_PORT 8080
ENV APP_HOME /usr/app
ENV APP_TARGET_MODULE wsgi
ENV APP_TARGET_APP app
ENV APP_WORKERS_NO 1
ENV APP_CONFIG_PATH config.py
ENV APP_ACCESS_LOG_FILE -
ENV APP_ERROR_LOG_FILE -

ENV PROMETHEUS_MULTIPROC_DIR ${APP_HOME}/metrics
ENV prometheus_multiproc_dir ${APP_HOME}/metrics

# Adding doas pacakge, an alternative to sudo package
# RUN apk add doas && \
#     # Following least privilege principle, to ensure we don't provide root access to our container default user
#     addgroup -g 3000 -S python && \
#     adduser -u 3000 -G python -S python

# RUN mkdir -p ${APP_HOME} && chown python:python ${APP_HOME}
RUN mkdir -p ${APP_HOME}
WORKDIR ${APP_HOME}

# Create multi-proc metrics data store directory
# RUN mkdir -p ${PROMETHEUS_MULTIPROC_DIR} && chown python:python ${PROMETHEUS_MULTIPROC_DIR}
RUN mkdir -p ${PROMETHEUS_MULTIPROC_DIR}

# Making use of docker layer caching by separating the dependencies from the source code
# COPY --chown=python:python requirements.txt .
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Adding source code
# COPY --chown=python:python . .
COPY . .

# su python
# USER 3000

EXPOSE ${APP_PORT}

CMD gunicorn --access-logfile ${APP_ACCESS_LOG_FILE} --error-logfile ${APP_ERROR_LOG_FILE} -c ${APP_CONFIG_PATH} -w ${APP_WORKERS_NO} -b ${APP_IP_ADDRESS}:${APP_PORT} ${APP_TARGET_MODULE}:${APP_TARGET_APP}