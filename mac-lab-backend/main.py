from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import subprocess

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # allow Flutter web
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/status")
def get_status():
    result = subprocess.run(
        ["fish", "-c", "mac-all status"],
        capture_output=True,
        text=True
    )
    return {"raw": result.stdout}
