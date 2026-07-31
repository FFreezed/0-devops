import time, json, random
import sys

levels = ["INFO", "WARN", "ERROR"]

while True:
    status = random.choice(levels)

    if status == "ERROR":
        msg = "Database connection timeout!"
    elif status == "WARN":
        msg = "Latency longer than expected!"
    elif status == "INFO":
        msg = "Backup database"
    else:
        msg = "Transaction processed safely"

    log_data = {
        "timestamp": time.time(),
        "level": status,
        "service": "payment-service",
        "message": msg
    }

    json_output = json.dumps(log_data)
    print(json_output)
    sys.stdout.flush()
    time.sleep(3)
