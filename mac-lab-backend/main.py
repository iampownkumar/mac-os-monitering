from fastapi import FastAPI, HTTPException
import subprocess, re, time, os
from pydantic import BaseModel
from fastapi.responses import StreamingResponse
import subprocess
import os


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


class BrewRequest(BaseModel):
    type: str   # "cask" or "formula"
    name: str   # "firefox", "iterm2", "visual-studio-code", etc.

@app.post("/brew/install/{id}")
def brew_install(id: int, req: BrewRequest):
    num = str(id).zfill(3)
    host = f"mac-{num}"

    cmd = f"mac-brew mac {id} {req.type} {req.name}"

    try:
        result = subprocess.run(
            ["/opt/homebrew/bin/fish", "-c", cmd],
            capture_output=True,
            text=True,
            timeout=600
        )

        return {
            "host": host,
            "ok": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



RUNNING = {}

@app.get("/brew/install/{mac_id}/stream")
def brew_install_stream(mac_id: str, type: str, name: str):
    host = f"mac-{mac_id.zfill(3)}"

    cmd = [
        "ssh",
        "-o", "ConnectTimeout=6",
        "-o", "ConnectionAttempts=1",
        f"ritmaclab@{host}.local",
        f"HOMEBREW_NO_AUTO_UPDATE=1 /opt/homebrew/bin/brew install --{type} {name}"
    ]

    def stream():
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )

        RUNNING[host] = process

        yield f"[{host}] Starting install: {name} ({type})\n"

        try:
            if process.stdout is not None:
                for line in process.stdout:
                    yield line
            else:
                # No stdout available; wait for process to finish and report
                rc = process.wait()
                RUNNING.pop(host, None)
                yield f"\n[{host}] ❌ No stdout available (rc={rc})\n"
                return
        except GeneratorExit:
            process.kill()
            yield f"\n[{host}] ⛔ Manually stopped\n"
            return

        rc = process.wait()
        RUNNING.pop(host, None)

        if rc == 0:
            yield f"\n[{host}] ✅ Completed\n"
        else:
            yield f"\n[{host}] ❌ Failed or timeout\n"

    return StreamingResponse(stream(), media_type="text/plain")

@app.post("/brew/stop/{mac_id}")
def stop_brew(mac_id: str):
    host = f"mac-{mac_id.zfill(3)}"
    proc = RUNNING.get(host)

    if proc and proc.poll() is None:
        proc.kill()
        return {"ok": True, "msg": f"{host} stopped"}
    return {"ok": False, "msg": "No running job"}
