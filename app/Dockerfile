# --- Stage 1: The Build Environment ---
FROM python:3.11-alpine AS builder
WORKDIR /usr/src/app

# Patch OS system libraries and install app dependencies to a localized directory
RUN apk update && apk upgrade --no-cache \
    && pip install --no-cache-dir --target=/usr/src/app/deps fastapi>=0.115.0 uvicorn>=0.31.0

# --- Stage 2: The Hardened Production Runtime ---
FROM python:3.11-alpine
WORKDIR /usr/src/app

# Force an OS security upgrade on the final runtime layer to catch xz-libs
RUN apk update && apk upgrade --no-cache

# Explicitly create our secure unprivileged system runner
RUN adduser -D -s /bin/sh internal-app-runner

# Copy ONLY the raw, verified dependencies from the builder stage
COPY --from=builder /usr/src/app/deps /usr/local/lib/python3.11/site-packages
COPY --chown=internal-app-runner:internal-app-runner . .

# Set execution rights exclusively to the non-root user
USER internal-app-runner

EXPOSE 8080

CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8080"]