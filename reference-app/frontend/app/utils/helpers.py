from app import _logger

import os


def get_host():
    host = os.getenv('HOSTNAME', os.uname()[1])
    _logger.info(f"Set 'host' label to '{host}'")
    return host


def get_namespace():
    NAMESPACE_FILE = "/var/run/secrets/kubernetes.io/serviceaccount/namespace"
    namespace = os.uname()[1]
    if os.path.exists(NAMESPACE_FILE):
        _logger.info(f"Found {NAMESPACE_FILE}")
        try:
            with open(NAMESPACE_FILE, 'r') as file:
                namespace = file.read()
        except Exception as e:
            _logger.error(
                f"Error: Unable to read {NAMESPACE_FILE} reason='{str(e)}'")
    _logger.info(f"Set 'namespace' label to '{namespace}'")
    return namespace
