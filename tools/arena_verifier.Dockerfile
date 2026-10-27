# Private outbound worker. Mount operator-verified code/data read-only.
FROM python:3.12-alpine@sha256:6d43704baacd1bfbe7c295d7f13079d5d8104ed33568873133f8fc69980419df
RUN apk add --no-cache luajit libcrypto3
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
USER 1044:100
ENTRYPOINT ["python3", "/app/tools/arena_verifier_worker.py", "--config", "/config/worker.json"]
