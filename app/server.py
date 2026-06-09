from fastapi import FastAPI, Request
from datetime import datetime
import os

app = FastAPI(
    title="Secure Cloud Container Application",
    docs_url=None,      # Hardening: Disable Swagger UI exposure
    redoc_url=None      # Hardening: Disable ReDoc UI exposure
)

# Secure Production Headers Middleware
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response

@app.get("/")
async def read_root():
    return {
        "status": "active",
        "scope": "production",
        "message": "Secure Containerised Infrastructure Operational."
    }

# AWS Load Balancer Deep Health Check Route
@app.get("/health")
async def validation_health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "environment": os.getenv("NODE_ENV", "production")
    }