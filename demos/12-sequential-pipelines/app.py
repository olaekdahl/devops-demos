# Sample FastAPI app used across most demos.
# Kept intentionally small: one file, no framework abstractions, easy to teach.
import os
import random
from fastapi import FastAPI

app = FastAPI(title="DevOps Demo App")

VERSION = "1.0.0"

TIPS = [
    "Always run 'terraform plan' before 'terraform apply'—unless you like surprises!",
    "Continuous Integration: because 'it works on my machine' isn't enough.",
    "Remember: DevOps is a culture, not just a job title.",
    "If it's not in version control, did it ever really exist?",
    "You can't spell 'automation' without 'auto.' Wait, that was obvious.",
    "Use infrastructure as code. Pets are cute, but we prefer cattle in the cloud!",
    "Monitoring: Because we like to know when things break…immediately.",
    "CI/CD pipelines: Embrace the 'merge, build, test, deploy' Zen cycle.",
]


@app.get("/")
def root():
    return {
        "message": "Welcome to the DevOps Demo App!",
        "available_endpoints": ["/health", "/version", "/env", "/tips"],
    }


@app.get("/health")
def health():
    # Liveness/readiness probe target. Keep it cheap and dependency-free.
    return {"status": "OK", "message": "The application is healthy!"}


@app.get("/version")
def version():
    return {"version": VERSION}


@app.get("/env")
def env():
    # Demonstrates 12-factor config: read from env vars, never hardcode secrets.
    return {
        "app_name": os.getenv("APP_NAME", "DevOps Demo App"),
        "environment": os.getenv("ENVIRONMENT", "dev"),
        "secret_key": os.getenv("SECRET_KEY", "not-set"),
    }


@app.get("/tips")
def tips():
    return {"tip": random.choice(TIPS)}


@app.get("/login")
def login():
    return {"status": "authenticated"}


@app.get("/logout")
def logout():
    return {"status": "logged out"}
