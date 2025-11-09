FROM node:22-bookworm-slim

# Copy built backend
COPY ./packages/backend/server /app

# Copy built frontend distributions
COPY ./packages/frontend/apps/web/dist /app/static
COPY ./packages/frontend/admin/dist /app/static/admin
COPY ./packages/frontend/apps/mobile/dist /app/static/mobile

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends openssl libjemalloc2 && \
    rm -rf /var/lib/apt/lists/*

# Enable jemalloc for better memory performance
ENV LD_PRELOAD=libjemalloc.so.2

# Expose port
EXPOSE 3010

CMD ["node", "./dist/main.js"]
