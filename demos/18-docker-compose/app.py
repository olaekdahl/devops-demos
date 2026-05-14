import os
import psycopg
import redis
from fastapi import FastAPI

app = FastAPI()
DB_DSN = os.getenv("DB_DSN", "postgresql://app:app@db:5432/app")
RDS_HOST = os.getenv("REDIS_HOST", "cache")

r = redis.Redis(host=RDS_HOST, port=6379, decode_responses=True)


@app.get("/")
def root():
    return {"msg": "compose demo", "endpoints": ["/health", "/visit"]}


@app.get("/health")
def health():
    # Verifies app + Postgres + Redis all reachable.
    with psycopg.connect(DB_DSN) as conn:
        conn.execute("SELECT 1").fetchone()
    r.ping()
    return {"status": "OK"}


@app.get("/visit")
def visit():
    n = r.incr("visits")
    return {"visits": n}
