import os
try:
    from celery import Celery
except Exception:
    Celery = None

if Celery:
    broker = os.getenv('CELERY_BROKER_URL', 'redis://localhost:6379/0')
    app = Celery('backend', broker=broker)
else:
    app = None
