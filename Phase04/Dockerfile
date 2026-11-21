# Azure Vote sample source is cloned from Microsoft's public repository by prepare.
# Lab-only image. Review dependencies/vulnerabilities; do not use for sensitive production workloads.
FROM python:3.12-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1
WORKDIR /app
RUN pip install --no-cache-dir "Flask==3.1.2" "redis==6.4.0" "gunicorn==23.0.0"
COPY vendor/azure-vote/ /app/
EXPOSE 80
# Phase 03 Container Apps ingress targets port 80; preserve this contract.
CMD ["gunicorn", "--bind", "0.0.0.0:80", "--workers", "2", "--threads", "2", "main:app"]
