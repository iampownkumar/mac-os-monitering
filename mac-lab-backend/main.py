from fastapi import FastAPI, HTTPException
import subprocess
import os 
import time

app = FastAPI()

FISH = "/opt/homebrew/bin/fish"

import re
import time

@app.get("/status")
def get_status():
    result = subprocess.run(
        [FISH, "-l", "-c", "mac-all status"],
        capture_output=True,
        text=True,
        timeout=15
    )

    status = {}
    for line in result.stdout.splitlines():
        # remove ANSI color codes
        clean = re.sub(r'\x1B\[[0-9;]*m', '', line).strip()

        if clean.startswith("mac-"):
            name, rest = clean.split(":", 1)
            status[name.strip()] = "ONLINE" in rest

    return {
        "machines": status,
        "ts": time.time()
    }


@app.post("/reboot/{host}")
def reboot_host(host: str):
    if not host.startswith("mac-"):
        raise HTTPException(status_code=400, detail="Invalid host")

    full_host = f"ritmaclab@{host}.local"

    try:
        result = subprocess.run(
            ["ssh", full_host, "sudo", "/sbin/reboot"],
            capture_output=True,
            text=True,
            timeout=10
        )

        return {
            "host": host,
            "ok": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.post("/shutdown-all")
def shutdown_all():
    try:
        result = subprocess.run(
            ["/opt/homebrew/bin/fish", "-c", "mac-all down"],
            capture_output=True,
            text=True,
            timeout=30
        )

        return {
            "ok": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr
        }

    except Exception as e:
        return {"error": str(e)}

@app.post("/shutdown/{host}")
def shutdown_host(host: str):
    if not host.startswith("mac-"):
        raise HTTPException(status_code=400, detail="Invalid host")

    full_host = f"ritmaclab@{host}.local"

    try:
        result = subprocess.run(
            ["ssh", "-t", full_host, "sudo", "/sbin/shutdown", "-h", "now"],
            capture_output=True,
            text=True,
            timeout=10
        )

        return {
            "host": host,
            "ok": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    
@app.post("/reboot-all")
def reboot_all():
    result = subprocess.run(
        ["/opt/homebrew/bin/fish", "-c", "mac-all reboot"],
        capture_output=True,
        text=True,
        timeout=30
    )
    return {"ok": result.returncode == 0}

@app.post("/backend/start")
def start_backend():
    subprocess.run(["launchctl", "load", os.path.expanduser("~/Library/LaunchAgents/com.pown.maclab.backend.plist")])
    return {"ok": True}

@app.post("/backend/stop")
def stop_backend():
    subprocess.run(["launchctl", "unload", os.path.expanduser("~/Library/LaunchAgents/com.pown.maclab.backend.plist")])
    return {"ok": True}


# INFO:     Stopping reloader process [15742]
# (venv) pownkumar@admin-pc ~/c/f/m/mac-lab-backend (main)> cd /Users/pownkumar/code/flutter/main/mac-lab-backend
#                                                           python3 -m venv venv
#                                                           source venv/bin/activate.fish
# (venv) pownkumar@admin-pc ~/c/f/m/mac-lab-backend (main)> 