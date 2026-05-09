# Pinned base by digest — never use `python:3.12-slim` directly in production.
# Look up current digest with: docker buildx imagetools inspect python:3.12-slim
FROM python:3.12-slim@sha256:e55523f127124e5edc103ba201ce8453b7ae4e0e7f4ac1dab29cd38f1b3d4ae5 AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.12-slim@sha256:e55523f127124e5edc103ba201ce8453b7ae4e0e7f4ac1dab29cd38f1b3d4ae5
WORKDIR /app
RUN useradd --create-home --shell /bin/bash appuser
COPY --from=builder /root/.local /home/appuser/.local
COPY app.py .
RUN chown -R appuser:appuser /app
USER appuser
ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health').status==200 else 1)"
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
