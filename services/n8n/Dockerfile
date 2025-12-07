# 1. Base Image: Use Node-Debian (lts-slim) for Playwright compatibility (glibc)
FROM node:lts-slim

# Set environment variables for n8n
ENV NODE_ENV production
ENV N8N_DATA_FOLDER /home/node/.n8n
ENV PNPM_HOME /usr/local/lib/pnpm
ENV PATH $PNPM_HOME:$PATH

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

USER root
RUN npm install -g pnpm n8n playwright

RUN pnpm install -g n8n-nodes-playwright


RUN chown -R node:node /usr/local/lib/node_modules/ \
    && chown -R node:node /usr/local/bin/ \
    && mkdir -p $N8N_DATA_FOLDER \
    && chown -R node:node $N8N_DATA_FOLDER

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libnss3 libnspr4 libatk1.0-0 libcups2 libdrm2 libdbus-1-3 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 \
    fonts-liberation \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

USER node
RUN npx playwright install chromium

USER node
EXPOSE 5678
CMD ["n8n", "start"]
