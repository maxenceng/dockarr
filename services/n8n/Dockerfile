# Start from the official n8n image
FROM n8nio/n8n:1.123.3

# Switch to root user temporarily to install system dependencies
USER root

# Install Playwright's required system dependencies (for Debian-based images, which n8n uses)
# These are essential libraries for the browser to run inside the container.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    && rm -rf /var/lib/apt/lists/*

# Install the Playwright browser binaries
# The --with-deps flag ensures any other Node-level dependencies are installed.
# We explicitly install 'chromium' to save space over installing all three browsers.
RUN npx playwright install --with-deps chromium

# Switch back to the non-root user (node) for security
USER node