# I am referencing the image digest to ensure deterministic build
FROM python:3.8-alpine@sha256:9e8a162cd85c78458ac47457b08450be8ca4ae5de5ee0f7b23665b6ea2569aed

ENV APP_HOME /usr/app
ENV APP_PORT 8080
ENV PROMETHEUS_MULTIPROC_DIR "${APP_HOME}"
ENV prometheus_multiproc_dir "${APP_HOME}"

# Adding doas pacakge, an alternative to sudo package
RUN apk add doas && \
    # Following least privilege principle, to ensure we don't provide root access to our container default user
    addgroup -g 3000 -S python && \
    adduser -u 3000 -G python -S python

RUN mkdir -p "${APP_HOME}" && chown python:python "${APP_HOME}"
WORKDIR "${APP_HOME}"

# Making use of docker layer caching by separating the dependencies from the source code
COPY --chown=python:python requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Adding source code
COPY --chown=python:python . .

# su python
USER 3000

EXPOSE "${APP_PORT}"

CMD [ "gunicorn", "--access-logfile", "-", "--error-logfile", "-", "-c", "config.py", "-w", "4", "-b", "0.0.0.0:${APP_PORT}", "app:app" ]