# Start from the official n8n image (which is Alpine-based)
FROM n8nio/n8n:1.123.3

# --- 1. Install n8n Community Node ---
# Install the playwright node
USER node
RUN npm install n8n-nodes-playwright

# --- 2. Install System Dependencies & Glibc Compatibility ---
# Switch to root to install system dependencies (using apk for Alpine)
USER root
RUN apk update && \
    apk add --no-cache \
    chromium \
    font-dejavu \
    gcompat \
    && rm -rf /var/cache/apk/*

# --- 3. Install Playwright Browser Binaries ---
# Switch back to the 'node' user to install the browser into the correct user path
USER node
# Install the browser binary itself. We rely on the gcompat package for the system libs.
RUN npx playwright install chromium

# --- 4. Final Security ---
USER node