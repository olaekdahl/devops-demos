# Tiny "service" — prints a heartbeat. Stands in for a real app for the demo.
import time, os
version = os.getenv("APP_VERSION", "1.0.0")
while True:
    print(f"[heartbeat] version={version} ts={time.time():.0f}", flush=True)
    time.sleep(2)
