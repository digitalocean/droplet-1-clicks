import os

# Chart and metadata caches use Flask-Caching's filesystem backend so this
# Droplet does not need Redis. Dashboard filter state and Explore form data
# stay on Superset's default metastore cache in the metadata database.
_CACHE_DIR = os.environ.get("SUPERSET_CACHE_DIR", "/app/superset_home/cache")

CACHE_CONFIG = {
    "CACHE_TYPE": "FileSystemCache",
    "CACHE_DIR": os.path.join(_CACHE_DIR, "metadata"),
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_meta_",
}

DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "FileSystemCache",
    "CACHE_DIR": os.path.join(_CACHE_DIR, "data"),
    "CACHE_DEFAULT_TIMEOUT": 60 * 60 * 24,
    "CACHE_KEY_PREFIX": "superset_data_",
}

# Caddy terminates TLS and sends X-Forwarded-* for the original request.
ENABLE_PROXY_FIX = True
PROXY_FIX_CONFIG = {"x_for": 1, "x_proto": 1, "x_host": 1, "x_port": 1, "x_prefix": 1}
PREFERRED_URL_SCHEME = "https"
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_SAMESITE = "Lax"

# This image does not run a Redis broker or Celery worker.
CELERY_CONFIG = None
