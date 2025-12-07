# Start from the official n8n image (which is Alpine-based)
FROM n8nio/n8n:1.123.3

USER node
RUN npm install n8n-nodes-playwright

# Switch to root user temporarily to install system dependencies
USER root

# Install Playwright's required core dependencies using apk (This should be correct now)
RUN apk update && \
    apk add --no-cache \
    chromium \
    font-dejavu \
    && rm -rf /var/cache/apk/*

# Install the Playwright browser binaries WITHOUT system dependencies
# This prevents Playwright from attempting to use apt-get.
RUN npx playwright install chromium

# Switch back to the non-root user (node) for security
USER node