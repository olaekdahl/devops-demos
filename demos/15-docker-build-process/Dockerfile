# Use the official slim Python image — small, well-maintained.
FROM python:3.12-slim

# All subsequent commands run from /app.
WORKDIR /app

# 1) Copy ONLY requirements first → cache-friendly layer.
COPY requirements.txt .

# 2) Install deps. --no-cache-dir keeps the image small.
RUN pip install --no-cache-dir -r requirements.txt

# 3) Copy the rest of the source (this layer changes most often).
COPY . .

# Document the port; does NOT publish it (that's `-p` on `docker run`).
EXPOSE 8000

# Run as a non-root user (security best practice).
RUN useradd --create-home --shell /bin/bash app && chown -R app /app
USER app

# Default command: launch FastAPI via uvicorn.
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
