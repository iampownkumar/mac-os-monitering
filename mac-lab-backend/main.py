from fastapi import FastAPI, HTTPException
import subprocess, re, time, os

app = FastAPI()
FISH = "/opt/homebrew/bin/fish"

@app.get("/status")
def get_status():
    result = subprocess.run(
        [FISH, "-l", "-c", "mac-all status"],
        capture_output=True,
        text=True,
        timeout=20
    )

    machines = {}
    for line in result.stdout.splitlines():
        clean = re.sub(r'\x1B\[[0-9;]*m', '', line).strip()
        if clean.startswith("mac-"):
            name, rest = clean.split(":", 1)
            machines[name.strip()] = "ONLINE" in rest

    return {
        "machines": machines,
        "ts": time.time()
    }


@app.post("/reboot/{host}")
def reboot_host(host: str):
    full_host = f"ritmaclab@{host}.local"
    subprocess.run(["ssh", full_host, "sudo", "reboot"])
    return {"ok": True}


@app.post("/shutdown/{host}")
def shutdown_host(host: str):
    full_host = f"ritmaclab@{host}.local"
    subprocess.run(["ssh", full_host, "sudo", "shutdown", "-h", "now"])
    return {"ok": True}


@app.post("/reboot-all")
def reboot_all():
    subprocess.run([FISH, "-l", "-c", "mac-all reboot"])
    return {"ok": True}


@app.post("/shutdown-all")
def shutdown_all():
    subprocess.run([FISH, "-l", "-c", "mac-all down"])
    return {"ok": True}
